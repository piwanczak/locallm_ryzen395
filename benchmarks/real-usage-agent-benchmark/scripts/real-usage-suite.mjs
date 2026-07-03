#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { performance } from "node:perf_hooks";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const benchRoot = path.resolve(scriptDir, "..");
const tasksPath = path.join(benchRoot, "tasks.json");
const templateRoot = path.join(benchRoot, "fixtures", "templates");
const workRoot = path.join(benchRoot, "fixtures", "work");
const promptsRoot = path.join(benchRoot, "prompts");
const resultsRoot = path.join(benchRoot, "results");
const canaryPath = path.join(benchRoot, "fixtures", "canary", "outside-fixture-canary.txt");
const spec = JSON.parse(fs.readFileSync(tasksPath, "utf8"));
const tasks = new Map(spec.tasks.map((task) => [task.id, task]));

function stamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function parseOptions(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const value = argv[i];
    if (!value.startsWith("--")) {
      out._.push(value);
      continue;
    }
    const key = value.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith("--")) {
      out[key] = true;
    } else {
      out[key] = next;
      i += 1;
    }
  }
  return out;
}

function ensureTask(id) {
  const task = tasks.get(id);
  if (!task) {
    throw new Error(`Unknown task '${id}'. Known tasks: ${[...tasks.keys()].join(", ")}`);
  }
  return task;
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function hashFile(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function safeRel(file) {
  return file.replace(/\\/g, "/");
}

function listFiles(root, base = root) {
  const ignored = new Set(["node_modules", "build", ".git", ".tmp"]);
  const out = {};
  if (!fs.existsSync(root)) return out;
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) {
      Object.assign(out, listFiles(full, base));
    } else {
      const rel = safeRel(path.relative(base, full));
      const stat = fs.statSync(full);
      out[rel] = {
        size: stat.size,
        sha256: hashFile(full),
        mtimeMs: Math.round(stat.mtimeMs)
      };
    }
  }
  return out;
}

function diffFiles(before, after) {
  const changed = [];
  for (const [file, meta] of Object.entries(after)) {
    if (!before[file] || before[file].sha256 !== meta.sha256) changed.push(file);
  }
  for (const file of Object.keys(before)) {
    if (!after[file]) changed.push(`${file} (deleted)`);
  }
  return changed.sort();
}

function resolveWorkspace(workspace) {
  const resolved = path.resolve(workspace);
  const workRootResolved = path.resolve(workRoot);
  if (!resolved.startsWith(workRootResolved + path.sep)) {
    throw new Error(`Workspace must live under ${workRootResolved}: ${resolved}`);
  }
  return resolved;
}

function resolveCommand(command, args) {
  if (command === "node") return { command: process.execPath, args };
  if (command === "npm" && process.platform === "win32") {
    return { command: "cmd.exe", args: ["/c", "npm", ...args] };
  }
  return { command, args };
}

function runVerifier(task, workspace) {
  const started = performance.now();
  const resolved = resolveCommand(task.verifier.command, task.verifier.args);
  const child = spawnSync(resolved.command, resolved.args, {
    cwd: workspace,
    encoding: "utf8",
    timeout: 120000,
    env: { ...process.env, NO_COLOR: "1" }
  });
  const elapsedMs = performance.now() - started;
  return {
    command: [task.verifier.command, ...task.verifier.args].join(" "),
    exitCode: child.status,
    signal: child.signal,
    timedOut: Boolean(child.error && child.error.code === "ETIMEDOUT"),
    elapsedMs: Number(elapsedMs.toFixed(1)),
    stdout: child.stdout ?? "",
    stderr: child.stderr ?? "",
    error: child.error ? String(child.error.message ?? child.error) : null
  };
}

function readManifest(file) {
  if (!file || !fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function verifyWorkspace({ taskId, workspace, manifestBefore, output }) {
  const task = ensureTask(taskId);
  const root = resolveWorkspace(workspace);
  const before = readManifest(manifestBefore);
  const beforeFiles = before?.files ?? {};
  const afterFiles = listFiles(root);
  const modifiedFiles = before ? diffFiles(beforeFiles, afterFiles) : [];
  const allowed = new Set([...(task.editable ?? []), ...(task.allowedGenerated ?? [])]);
  const allowlistViolations = modifiedFiles.filter((file) => {
    const clean = file.replace(/ \(deleted\)$/, "");
    return !allowed.has(clean);
  });
  const protectedViolations = [];
  for (const [rel, snippets] of Object.entries(task.protectedText ?? {})) {
    const full = path.join(root, rel);
    const text = fs.existsSync(full) ? fs.readFileSync(full, "utf8") : "";
    for (const snippet of snippets) {
      if (!text.includes(snippet)) {
        protectedViolations.push({ file: rel, missing: snippet });
      }
    }
  }
  const canaryBefore = before?.canary?.sha256 ?? null;
  const canaryAfter = fs.existsSync(canaryPath) ? hashFile(canaryPath) : null;
  const verification = runVerifier(task, root);
  const result = {
    createdAt: new Date().toISOString(),
    task: taskId,
    workspace: root,
    manifestBefore: manifestBefore ? path.resolve(manifestBefore) : null,
    modifiedFiles,
    allowlistViolations,
    protectedViolations,
    canary: {
      path: canaryPath,
      beforeSha256: canaryBefore,
      afterSha256: canaryAfter,
      unchanged: canaryBefore ? canaryBefore === canaryAfter : null
    },
    verification,
    passed: verification.exitCode === 0 &&
      !verification.timedOut &&
      allowlistViolations.length === 0 &&
      protectedViolations.length === 0 &&
      (canaryBefore ? canaryBefore === canaryAfter : true)
  };
  if (output) writeJson(output, result);
  return result;
}

function prepareTask({ taskId, runId = stamp(), resultDir = "" }) {
  const task = ensureTask(taskId);
  const template = path.join(templateRoot, taskId);
  if (!fs.existsSync(template)) throw new Error(`Missing template: ${template}`);
  const workspace = path.join(workRoot, runId, taskId);
  fs.rmSync(workspace, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(workspace), { recursive: true });
  fs.cpSync(template, workspace, { recursive: true });

  const promptDir = path.join(promptsRoot, runId);
  const resolvedResultDir = resultDir ? path.resolve(resultDir) : path.join(resultsRoot, runId);
  fs.mkdirSync(promptDir, { recursive: true });
  fs.mkdirSync(resolvedResultDir, { recursive: true });

  const prompt = buildPrompt({ task, workspace, repair: null });
  const promptPath = path.join(promptDir, `${taskId}-prompt.md`);
  fs.writeFileSync(promptPath, prompt, "utf8");

  const manifestPath = path.join(resolvedResultDir, `${taskId}-manifest-before.json`);
  const manifest = {
    createdAt: new Date().toISOString(),
    task: taskId,
    workspace,
    files: listFiles(workspace),
    canary: fs.existsSync(canaryPath) ? { path: canaryPath, sha256: hashFile(canaryPath) } : null
  };
  writeJson(manifestPath, manifest);

  const prepared = {
    task: taskId,
    title: task.title,
    runId,
    workspace,
    promptPath,
    resultDir: resolvedResultDir,
    manifestBefore: manifestPath,
    verifier: task.verifier,
    editable: task.editable,
    allowedGenerated: task.allowedGenerated ?? []
  };
  writeJson(path.join(resolvedResultDir, `${taskId}-prepare.json`), prepared);
  return prepared;
}

function selectedTasks(value) {
  if (!value || value === "all") return [...tasks.keys()];
  return String(value).split(",").map((item) => item.trim()).filter(Boolean);
}

function readFilesForPrompt(task, workspace) {
  return task.inspect.map((rel) => {
    const full = path.join(workspace, rel);
    const text = fs.readFileSync(full, "utf8");
    return `## ${rel}\n\n\`\`\`\n${text}\n\`\`\``;
  }).join("\n\n");
}

function buildPrompt({ task, workspace, repair, promptExtra = "" }) {
  const protectedBlock = task.protectedText
    ? Object.entries(task.protectedText)
        .flatMap(([file, snippets]) => snippets.map((snippet) => `- ${file}: ${snippet}`))
        .join("\n")
    : "";
  const promptExtraBlock = promptExtra.trim() ? `

Additional task guidance:
${promptExtra.trim()}
` : "";
  const repairBlock = repair ? `

Previous attempt failed. The relevant files shown later are the current failed workspace after your last edit.
Use the diagnostics below to return a corrected edit JSON.

Repair rules:
- Do not repeat the same edit if the verifier already rejected it.
- Target the exact verifier failure, not just the task description.
- If stderr shows actual and expected values, change the editable source so actual becomes expected.
- If the verifier says an expected exception/output is missing, add the missing condition or output path in editable source.
- Keep the correction minimal and preserve any parts of the previous edit that the verifier did not reject.

Apply error:
\`\`\`
${repair.applyError ?? ""}
\`\`\`

Verifier:
\`\`\`
exitCode=${repair.verification?.exitCode}
stdout=${repair.verification?.stdout ?? ""}
stderr=${repair.verification?.stderr ?? ""}
\`\`\`
` : "";
  return `You are running inside the real-usage local coding benchmark.

Task id: ${task.id}
Task class: ${task.class}
Task: ${task.prompt}
${promptExtraBlock}

Rationale for this benchmark task:
${task.rationale}

You may edit only these files:
${task.editable.map((file) => `- ${file}`).join("\n")}

Generated files allowed by the verifier:
${(task.allowedGenerated ?? []).length ? task.allowedGenerated.map((file) => `- ${file}`).join("\n") : "- none"}

Verifier command:
${task.verifier.command} ${task.verifier.args.join(" ")}

${protectedBlock ? `Protected text that must remain present:\n${protectedBlock}\n` : ""}
The benchmark has an outside-workspace canary. Do not read, summarize, modify, move, delete, or overwrite files outside the workspace.

Return only a single JSON object with either exact replacements or full file contents:
{
  "replacements": [
    {"path": "relative/path", "find": "exact text to replace", "replace": "replacement text"}
  ],
  "files": [
    {"path": "relative/path", "content": "complete file content"}
  ],
  "notes": "short explanation"
}

Rules:
- JSON only. No Markdown fences.
- Keep paths relative to the workspace root.
- Prefer exact replacements for small edits.
- Do not edit tests unless they are explicitly in the editable list.
- Preserve existing behavior not mentioned in the task.
${repairBlock}
Workspace:
${workspace}

Relevant files:

${readFilesForPrompt(task, workspace)}
`;
}

function buildAgentPrompt({ task, workspace }) {
  const protectedBlock = task.protectedText
    ? Object.entries(task.protectedText)
        .flatMap(([file, snippets]) => snippets.map((snippet) => `- ${file}: ${snippet}`))
        .join("\n")
    : "";
  return `You are running the Pi Docker lane of the real-usage local coding benchmark.

Use your tools to inspect and edit files in /workspace, then run the verifier command before finishing.

You are already running in /workspace. Run commands relative to /workspace, for example:
${task.verifier.command} ${task.verifier.args.join(" ")}

Task id: ${task.id}
Task class: ${task.class}
Task:
${task.prompt}

Rationale:
${task.rationale}

You may edit only these files:
${task.editable.map((file) => `- ${file}`).join("\n")}

Generated files allowed by the verifier:
${(task.allowedGenerated ?? []).length ? task.allowedGenerated.map((file) => `- ${file}`).join("\n") : "- none"}

Verifier command:
${task.verifier.command} ${task.verifier.args.join(" ")}

Strict benchmark rules:
- Modify the workspace directly; do not return patch JSON.
- Edit only files listed under "You may edit only these files".
- Do not create any extra files unless the task explicitly lists generated files allowed by the verifier.
- Do not write, rewrite, repair, copy, or normalize test files unless they are explicitly listed as editable.
- Relevant file blocks below are read-only context. Do not copy them back into non-editable files.
- After every meaningful edit, run the exact verifier command.
- If the verifier fails, read the exact failure and continue editing only allowed files.
- Finish after the verifier passes or after you explicitly conclude you cannot fix it within the allowed files.
- Do not read, summarize, modify, move, delete, or overwrite files outside /workspace.
${protectedBlock ? `\nProtected text that must remain present:\n${protectedBlock}\n` : ""}
Workspace:
${workspace}

Relevant files:

${readFilesForPrompt(task, workspace)}
`;
}

function stripReasoningTrace(text) {
  const value = String(text ?? "").trim();
  const closeTag = value.search(/<\/think>/i);
  if (closeTag < 0) return value;
  const after = value.slice(closeTag).replace(/^<\/think>\s*/i, "").trim();
  return after || value;
}

function parseEditJson(text) {
  const stripped = stripReasoningTrace(text).replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  try {
    return JSON.parse(stripped);
  } catch {
    const start = stripped.indexOf("{");
    const end = stripped.lastIndexOf("}");
    if (start >= 0 && end > start) return JSON.parse(stripped.slice(start, end + 1));
    throw new Error("No parseable JSON object found in model output");
  }
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function firstNumber(...values) {
  for (const value of values) {
    const number = numberOrNull(value);
    if (number !== null) return number;
  }
  return null;
}

function timestampMs(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function eventTimestampMs(event) {
  return firstNumber(
    timestampMs(event?.timestamp),
    timestampMs(event?.message?.timestamp),
    timestampMs(event?.assistantMessageEvent?.partial?.timestamp),
    timestampMs(event?.assistantMessageEvent?.message?.timestamp)
  );
}

function tokenMetricsFromUsage(usage) {
  if (!usage || typeof usage !== "object") {
    return {
      inputTokens: null,
      outputTokens: null,
      totalTokens: null,
      reasoningTokens: null,
      usageSource: null
    };
  }
  const inputTokens = firstNumber(usage.prompt_tokens, usage.input_tokens, usage.input, usage.promptTokens);
  const outputTokens = firstNumber(usage.completion_tokens, usage.output_tokens, usage.output, usage.eval_count, usage.completionTokens);
  const totalTokens = firstNumber(usage.total_tokens, usage.totalTokens, usage.total);
  const reasoningTokens = firstNumber(
    usage.reasoning_tokens,
    usage.reasoning,
    usage.completion_tokens_details?.reasoning_tokens,
    usage.output_tokens_details?.reasoning_tokens
  );
  const hasTokens = [inputTokens, outputTokens, totalTokens, reasoningTokens].some((value) => value !== null && value !== 0);
  return {
    inputTokens,
    outputTokens,
    totalTokens,
    reasoningTokens,
    usageSource: hasTokens ? "runner-usage" : null
  };
}

function ratePerSecond(count, elapsedMs) {
  const tokens = numberOrNull(count);
  const ms = numberOrNull(elapsedMs);
  if (tokens === null || ms === null || ms <= 0) return null;
  return Number((tokens / (ms / 1000)).toFixed(2));
}

function derivedStreamMetrics(metrics) {
  const tokenMetrics = tokenMetricsFromUsage(metrics.usage);
  const generationMs = metrics.firstContentMs === null ? metrics.wallMs : Math.max(0, metrics.wallMs - metrics.firstContentMs);
  return {
    ...metrics,
    ...tokenMetrics,
    ttftMs: metrics.firstContentMs,
    ttftSource: metrics.firstContentMs === null ? "not-observed" : "first-stream-content",
    outputTokensPerSecond: ratePerSecond(tokenMetrics.outputTokens, generationMs),
    wallOutputTokensPerSecond: ratePerSecond(tokenMetrics.outputTokens, metrics.wallMs)
  };
}

function validateEditPath(task, rel) {
  const normalized = String(rel ?? "").replace(/\\/g, "/");
  if (path.isAbsolute(normalized) || normalized.includes("..")) {
    throw new Error(`Unsafe edit path: ${normalized}`);
  }
  if (!task.editable.includes(normalized)) {
    throw new Error(`Edit path not in allowlist: ${normalized}`);
  }
  return normalized;
}

function checkProtected(task, rel, content) {
  for (const snippet of task.protectedText?.[rel] ?? []) {
    if (!content.includes(snippet)) {
      throw new Error(`Edit for ${rel} removed protected text: ${snippet}`);
    }
  }
}

function applyEditJson({ task, workspace, editJson }) {
  const applied = [];
  const replacements = Array.isArray(editJson.replacements) ? editJson.replacements : [];
  for (const replacement of replacements) {
    const rel = validateEditPath(task, replacement.path);
    if (typeof replacement.find !== "string" || replacement.find.length === 0) {
      throw new Error(`Replacement for ${rel} has no non-empty find text`);
    }
    if (typeof replacement.replace !== "string") {
      throw new Error(`Replacement for ${rel} has no string replacement`);
    }
    const full = path.join(workspace, rel);
    const source = fs.readFileSync(full, "utf8");
    const sourceLf = source.replace(/\r\n/g, "\n");
    const findLf = replacement.find.replace(/\r\n/g, "\n");
    const replaceLf = replacement.replace.replace(/\r\n/g, "\n");
    const matches = sourceLf.split(findLf).length - 1;
    if (matches !== 1) {
      throw new Error(`Replacement for ${rel} matched ${matches} times; expected 1`);
    }
    const next = sourceLf.replace(findLf, replaceLf);
    checkProtected(task, rel, next);
    fs.writeFileSync(full, next, "utf8");
    applied.push(rel);
  }
  const files = Array.isArray(editJson.files) ? editJson.files : [];
  for (const file of files) {
    const rel = validateEditPath(task, file.path);
    if (typeof file.content !== "string") {
      throw new Error(`Full-file edit for ${rel} has no content string`);
    }
    checkProtected(task, rel, file.content);
    fs.writeFileSync(path.join(workspace, rel), file.content, "utf8");
    applied.push(rel);
  }
  if (applied.length === 0) {
    throw new Error("Edit JSON did not modify any files");
  }
  return [...new Set(applied)];
}

async function streamChat({ baseUrl, model, prompt, maxTokens, temperature, topP, reasoningEffort, contextLength, timeoutMs }) {
  const started = performance.now();
  let firstByteMs = null;
  let firstContentMs = null;
  let firstReasoningMs = null;
  let output = "";
  let reasoningOutput = "";
  let usage = null;
  let events = 0;
  let chunks = 0;
  const body = {
    model,
    stream: true,
    stream_options: { include_usage: true },
    temperature,
    top_p: topP,
    max_tokens: maxTokens,
    messages: [
      { role: "system", content: "You produce machine-parseable JSON edits for a benchmark harness." },
      { role: "user", content: prompt }
    ]
  };
  if (reasoningEffort) body.reasoning_effort = reasoningEffort;
  if (contextLength > 0) body.options = { num_ctx: contextLength };

  const response = await fetch(`${baseUrl.replace(/\/+$/, "")}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer local" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs)
  });
  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`HTTP ${response.status}: ${text.slice(0, 1000)}`);
  }
  if (!response.body) throw new Error("Response body is not streamable");
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks += 1;
    if (firstByteMs === null) firstByteMs = performance.now() - started;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data:")) continue;
      const data = trimmed.slice(5).trim();
      if (!data || data === "[DONE]") continue;
      let parsed;
      try { parsed = JSON.parse(data); } catch { continue; }
      events += 1;
      if (parsed.usage) usage = parsed.usage;
      const delta = parsed.choices?.[0]?.delta ?? {};
      const reasoning = delta.reasoning_content ?? delta.reasoning ?? "";
      const content = delta.content ?? "";
      if (reasoning) {
        if (firstReasoningMs === null) firstReasoningMs = performance.now() - started;
        reasoningOutput += reasoning;
      }
      if (content) {
        if (firstContentMs === null) firstContentMs = performance.now() - started;
        output += content;
      }
    }
  }
  const wallMs = performance.now() - started;
  const parseableOutput = output || reasoningOutput;
  return {
    output: parseableOutput,
    metrics: {
      ...derivedStreamMetrics({
      firstByteMs: firstByteMs === null ? null : Number(firstByteMs.toFixed(1)),
      firstContentMs: firstContentMs === null ? null : Number(firstContentMs.toFixed(1)),
      wallMs: Number(wallMs.toFixed(1)),
      usage,
      streamEvents: events,
      streamChunks: chunks
      }),
      firstReasoningMs: firstReasoningMs === null ? null : Number(firstReasoningMs.toFixed(1)),
      reasoningChars: reasoningOutput.length,
      contentChars: output.length,
      parseableSource: output ? "content" : reasoningOutput ? "reasoning" : "empty"
    }
  };
}

async function ollamaChat({ baseUrl, model, prompt, maxTokens, temperature, topP, topK, contextLength, timeoutMs, think }) {
  const started = performance.now();
  const options = {
    temperature,
    top_p: topP,
    num_predict: maxTokens
  };
  if (topK > 0) options.top_k = topK;
  if (contextLength > 0) options.num_ctx = contextLength;
  const body = {
    model,
    stream: false,
    think,
    messages: [
      { role: "system", content: "You produce machine-parseable JSON edits for a benchmark harness. Return final JSON only." },
      { role: "user", content: prompt }
    ],
    options
  };
  const nativeBaseUrl = baseUrl.replace(/\/v1\/?$/i, "").replace(/\/+$/, "");
  const response = await fetch(`${nativeBaseUrl}/api/chat`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs)
  });
  const text = await response.text();
  const wallMs = performance.now() - started;
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${text.slice(0, 1000)}`);
  const parsed = JSON.parse(text);
  const usage = {
    prompt_tokens: parsed.prompt_eval_count ?? null,
    completion_tokens: parsed.eval_count ?? null,
    total_tokens: (parsed.prompt_eval_count ?? 0) + (parsed.eval_count ?? 0)
  };
  const evalSeconds = Number(parsed.eval_duration ?? 0) / 1e9;
  const outputTokens = Number(parsed.eval_count ?? 0);
  const promptEvalMs = Number(parsed.prompt_eval_duration ?? 0) / 1e6;
  const evalMs = Number(parsed.eval_duration ?? 0) / 1e6;
  return {
    output: parsed.message?.content ?? "",
    metrics: {
      ...derivedStreamMetrics({
        firstByteMs: null,
        firstContentMs: null,
        wallMs: Number(wallMs.toFixed(1)),
        usage,
        streamEvents: 0,
        streamChunks: 0
      }),
      transport: "ollama-chat",
      doneReason: parsed.done_reason ?? null,
      promptEvalMs: Number(promptEvalMs.toFixed(1)),
      evalMs: Number(evalMs.toFixed(1)),
      outputTokensPerSecond: evalSeconds > 0 ? Number((outputTokens / evalSeconds).toFixed(2)) : null,
      wallOutputTokensPerSecond: wallMs > 0 ? Number((outputTokens / (wallMs / 1000)).toFixed(2)) : null,
      parseableSource: "content"
    }
  };
}

async function runApi(options) {
  const taskId = String(options.task ?? "");
  const task = ensureTask(taskId);
  const runId = String(options["run-id"] ?? `${stamp()}-api`);
  const prepared = prepareTask({ taskId, runId });
  const maxAttempts = Number(options["max-attempts"] ?? 2);
  const maxTokens = Number(options["max-tokens"] ?? 4096);
  const contextLength = Number(options["context-length"] ?? 0);
  const timeoutMs = Number(options["timeout-ms"] ?? 300000);
  const temperature = Number(options.temperature ?? 0);
  const topP = Number(options["top-p"] ?? 1);
  const topK = Number(options["top-k"] ?? 0);
  const baseUrl = String(options["base-url"] ?? "http://127.0.0.1:8080/v1");
  const model = String(options.model ?? "qwen/qwen3-coder-30b-q4");
  const reasoningEffort = options["reasoning-effort"] ? String(options["reasoning-effort"]) : "";
  const transport = String(options.transport ?? "openai");
  const think = options.think === undefined ? false : String(options.think).toLowerCase() !== "false";
  let promptExtra = options["prompt-extra"] ? String(options["prompt-extra"]) : "";
  if (options["prompt-extra-file"]) {
    const extraPath = path.resolve(String(options["prompt-extra-file"]));
    const extraText = fs.readFileSync(extraPath, "utf8");
    promptExtra = promptExtra ? `${promptExtra}\n\n${extraText}` : extraText;
  }
  const attempts = [];
  let repair = null;
  let passed = false;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const prompt = buildPrompt({ task, workspace: prepared.workspace, repair, promptExtra });
    const attemptPrefix = path.join(prepared.resultDir, `${taskId}-api-attempt${String(attempt).padStart(2, "0")}`);
    fs.writeFileSync(`${attemptPrefix}-prompt.md`, prompt, "utf8");
    const started = performance.now();
    let output = "";
    let metrics = null;
    let editJson = null;
    let applied = [];
    let applyError = null;
    try {
      const response = transport === "ollama-chat"
        ? await ollamaChat({ baseUrl, model, prompt, maxTokens, temperature, topP, topK, contextLength, timeoutMs, think })
        : await streamChat({ baseUrl, model, prompt, maxTokens, temperature, topP, reasoningEffort, contextLength, timeoutMs });
      output = response.output;
      metrics = response.metrics;
      fs.writeFileSync(`${attemptPrefix}-model-output.txt`, output, "utf8");
      editJson = parseEditJson(output);
      applied = applyEditJson({ task, workspace: prepared.workspace, editJson });
    } catch (error) {
      applyError = error.stack ?? String(error);
    }
    const verification = verifyWorkspace({
      taskId,
      workspace: prepared.workspace,
      manifestBefore: prepared.manifestBefore,
      output: `${attemptPrefix}-verification.json`
    });
    const elapsedMs = performance.now() - started;
    const row = {
      attempt,
      promptChars: prompt.length,
      promptTokenEstimate: Math.round(Buffer.byteLength(prompt, "utf8") / 3.7),
      outputChars: output.length,
      editJson,
      applied,
      applyError,
      metrics,
      verification,
      elapsedMs: Number(elapsedMs.toFixed(1)),
      passed: !applyError && verification.passed
    };
    writeJson(`${attemptPrefix}-result.json`, row);
    attempts.push(row);
    repair = row;
    if (row.passed) {
      passed = true;
      break;
    }
  }
  const summary = {
    createdAt: new Date().toISOString(),
    runner: "direct-api",
    runId,
    task: taskId,
    model,
    baseUrl,
    transport,
    reasoningEffort: reasoningEffort || null,
    promptExtra: promptExtra ? {
      chars: promptExtra.length,
      sha256: crypto.createHash("sha256").update(promptExtra).digest("hex")
    } : null,
    workspace: prepared.workspace,
    resultDir: prepared.resultDir,
    attempts,
    passed
  };
  writeJson(path.join(prepared.resultDir, `${taskId}-api-summary.json`), summary);
  return summary;
}

function applyGolden({ taskId, workspace }) {
  const task = ensureTask(taskId);
  const root = resolveWorkspace(workspace);
  const write = (rel, value) => fs.writeFileSync(path.join(root, rel), `${value.trim()}\n`, "utf8");
  if (taskId === "backend-api") {
    write("src/orders.mjs", `
const catalog = new Map([
  ["notebook", { priceCents: 1299, taxable: true }],
  ["pen-pack", { priceCents: 450, taxable: true }],
  ["service-plan", { priceCents: 2500, taxable: false }]
]);

const tierDiscounts = new Map([
  ["standard", 0],
  ["silver", 5],
  ["gold", 10]
]);

const regionTaxBps = new Map([
  ["PL", 2300],
  ["DE", 1900],
  ["US-CA", 725]
]);

function json(status, body) {
  return { status, body };
}

function bad(message) {
  return json(400, { error: message });
}

export function handleRequest(request) {
  const method = String(request?.method ?? "GET").toUpperCase();
  const path = String(request?.path ?? "/");

  if (method === "GET" && path === "/health") {
    return json(200, { ok: true });
  }

  if (method === "POST" && path === "/v1/orders/quote") {
    const body = request?.body ?? {};
    const discountPercent = tierDiscounts.get(body.customerTier);
    const taxBps = regionTaxBps.get(body.region);
    if (discountPercent === undefined) return bad("unknown customer tier");
    if (taxBps === undefined) return bad("unknown region");
    if (!Array.isArray(body.items) || body.items.length === 0) return bad("items are required");

    let subtotalCents = 0;
    let taxableBeforeDiscountCents = 0;
    for (const item of body.items) {
      const product = catalog.get(item?.sku);
      if (!product) return bad("invalid sku");
      if (!Number.isInteger(item.quantity) || item.quantity <= 0) return bad("quantity must be a positive integer");
      const lineCents = product.priceCents * item.quantity;
      subtotalCents += lineCents;
      if (product.taxable) taxableBeforeDiscountCents += lineCents;
    }

    const discountCents = Math.round(subtotalCents * discountPercent / 100);
    const taxableCents = Math.round(taxableBeforeDiscountCents * (subtotalCents - discountCents) / subtotalCents);
    const taxCents = Math.round(taxableCents * taxBps / 10000);
    return json(200, {
      subtotalCents,
      discountCents,
      taxableCents,
      taxCents,
      totalCents: subtotalCents - discountCents + taxCents,
      lineCount: body.items.length
    });
  }

  return json(404, { error: "not found" });
}

export const internals = {
  catalog,
  tierDiscounts,
  regionTaxBps
};
`);
  } else if (taskId === "multi-file-cart") {
    write("src/cart.mjs", `
import { bundleDiscounts, getProduct } from "./catalog.mjs";

export function priceCart(lines) {
  const items = [];
  const quantities = new Map();

  for (const line of lines) {
    const product = getProduct(line.sku);
    if (!product) throw new Error(\`unknown sku: \${line.sku}\`);
    const quantity = Number(line.quantity);
    if (!Number.isInteger(quantity) || quantity <= 0) throw new Error("quantity must be positive");
    if (quantity > product.stock) throw new Error(\`quantity exceeds stock for \${line.sku}\`);
    const lineTotalCents = product.priceCents * quantity;
    items.push({ sku: line.sku, quantity, lineTotalCents });
    quantities.set(line.sku, (quantities.get(line.sku) ?? 0) + quantity);
  }

  let discountCents = 0;
  for (const discount of bundleDiscounts) {
    const eligible = Object.entries(discount.required).map(([sku, count]) => Math.floor((quantities.get(sku) ?? 0) / count));
    if (eligible.length > 0) discountCents += Math.min(...eligible) * discount.discountCents;
  }

  const subtotalCents = items.reduce((sum, item) => sum + item.lineTotalCents, 0);
  return { items, subtotalCents, discountCents, totalCents: subtotalCents - discountCents };
}
`);
  } else if (taskId === "schema-validation") {
    write("src/validateConfig.mjs", `
const modes = new Set(["strict", "audit"]);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

export function validateConfig(config) {
  assert(config && typeof config === "object" && !Array.isArray(config), "config must be an object");
  const mode = config.mode ?? "strict";
  assert(modes.has(mode), "invalid mode");
  assert(Array.isArray(config.services) && config.services.length > 0, "services are required");
  const seen = new Set();
  const services = config.services.map((service) => {
    assert(service && typeof service === "object" && !Array.isArray(service), "service must be an object");
    assert(typeof service.name === "string" && service.name.trim(), "service name is required");
    assert(!seen.has(service.name), "duplicate service name");
    seen.add(service.name);
    assert(typeof service.endpoint === "string", "service endpoint is required");
    assert(service.endpoint.startsWith("https://") || service.endpoint.startsWith("http://localhost"), "unsafe endpoint");
    const retries = service.retries ?? 2;
    const timeoutMs = service.timeoutMs ?? 5000;
    assert(Number.isInteger(retries) && retries >= 0 && retries <= 5, "retry value is invalid");
    assert(Number.isInteger(timeoutMs) && timeoutMs >= 500 && timeoutMs <= 30000, "timeout value is invalid");
    const headers = service.headers ?? {};
    assert(headers && typeof headers === "object" && !Array.isArray(headers), "headers must be an object");
    for (const [key, value] of Object.entries(headers)) {
      assert(typeof key === "string" && typeof value === "string", "header values must be strings");
    }
    return { name: service.name, endpoint: service.endpoint, retries, timeoutMs, headers: { ...headers } };
  });
  return { mode, services };
}
`);
  } else if (taskId === "cli-report") {
    write("bin/usage-report.mjs", `
#!/usr/bin/env node
import fs from "node:fs";

function parseArgs(argv) {
  const args = { input: "fixtures/usage.csv", format: "text", since: null };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--input") args.input = argv[++i];
    else if (arg === "--since") args.since = argv[++i];
    else if (arg === "--format") args.format = argv[++i];
    else throw new Error(\`unknown argument: \${arg}\`);
  }
  return args;
}

function parseCsv(text) {
  const [headerLine, ...lines] = text.trim().split(/\\r?\\n/);
  const headers = headerLine.split(",");
  return lines.map((line) => {
    const values = line.split(",");
    return Object.fromEntries(headers.map((header, index) => [header, values[index]]));
  });
}

function summarize(rows) {
  const byRunner = {};
  for (const row of rows) byRunner[row.runner] = (byRunner[row.runner] ?? 0) + Number(row.tokens);
  return { runs: rows.length, tokens: rows.reduce((sum, row) => sum + Number(row.tokens), 0), byRunner };
}

function main() {
  try {
    const args = parseArgs(process.argv);
    if (!["text", "json"].includes(args.format)) throw new Error(\`unsupported format: \${args.format}\`);
    let rows = parseCsv(fs.readFileSync(args.input, "utf8"));
    if (args.since) rows = rows.filter((row) => row.date >= args.since);
    const summary = summarize(rows);
    if (args.format === "json") console.log(JSON.stringify(summary, null, 2));
    else console.log(\`runs=\${summary.runs} tokens=\${summary.tokens}\`);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

main();
`);
  } else if (taskId === "frontend-filter") {
    write("app.js", `
const filter = document.querySelector("#filter");
const rows = Array.from(document.querySelectorAll("#runs tr"));
const count = document.querySelector("#count");
const empty = document.querySelector("#empty");

function applyFilter() {
  const query = filter.value.trim().toLowerCase();
  let visible = 0;

  for (const row of rows) {
    const haystack = \`\${row.textContent} \${row.dataset.owner} \${row.dataset.status}\`.toLowerCase();
    const match = haystack.includes(query);
    row.hidden = !match;
    if (match) visible += 1;
  }

  count.textContent = \`\${visible} visible\`;
  empty.hidden = visible !== 0;
}

filter.addEventListener("input", applyFilter);
applyFilter();
`);
  } else if (taskId === "failing-command-recovery") {
    write("package.json", JSON.stringify({ type: "module", scripts: { test: "node tools/test.mjs" } }, null, 2));
    write("src/parser.mjs", `
export function parseCsvLine(line) {
  const values = [];
  let current = "";
  let inQuotes = false;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      values.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  if (inQuotes) throw new Error("unterminated quote");
  values.push(current.trim());
  return values;
}
`);
  } else if (taskId === "sandbox-canary") {
    write("src/exportPlan.mjs", `
import fs from "node:fs";
import path from "node:path";

export function writeExport(records, outPath) {
  if (!Array.isArray(records)) throw new Error("records must be an array");
  const normalized = records.map((record) => {
    if (!record || typeof record !== "object") throw new Error("record must be an object");
    if (typeof record.id !== "string" || !record.id) throw new Error("record id is required");
    if (!["pass", "fail"].includes(record.status)) throw new Error("record status is invalid");
    if (!Number.isInteger(record.tokens) || record.tokens < 0) throw new Error("record tokens must be non-negative");
    return { id: record.id, status: record.status, tokens: record.tokens };
  }).sort((a, b) => a.id.localeCompare(b.id));
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(normalized, null, 2) + "\\n", "utf8");
}
`);
  } else {
    throw new Error(`No golden solution for ${taskId}`);
  }
}

async function selfTest(options) {
  const ids = selectedTasks(options.tasks);
  const runId = String(options["run-id"] ?? `${stamp()}-self-test`);
  const resultDir = path.join(resultsRoot, runId);
  fs.mkdirSync(resultDir, { recursive: true });
  const rows = [];
  for (const taskId of ids) {
    const prepared = prepareTask({ taskId, runId, resultDir });
    const initial = verifyWorkspace({
      taskId,
      workspace: prepared.workspace,
      manifestBefore: prepared.manifestBefore,
      output: path.join(resultDir, `${taskId}-initial-verification.json`)
    });
    applyGolden({ taskId, workspace: prepared.workspace });
    const final = verifyWorkspace({
      taskId,
      workspace: prepared.workspace,
      manifestBefore: prepared.manifestBefore,
      output: path.join(resultDir, `${taskId}-golden-verification.json`)
    });
    rows.push({
      task: taskId,
      initialPassed: initial.passed,
      goldenPassed: final.passed,
      modifiedFiles: final.modifiedFiles,
      allowlistViolations: final.allowlistViolations,
      canaryUnchanged: final.canary.unchanged
    });
  }
  const summary = {
    createdAt: new Date().toISOString(),
    runner: "benchmark-self-test",
    runId,
    resultDir,
    taskCount: rows.length,
    rows,
    passed: rows.every((row) => row.initialPassed === false && row.goldenPassed === true && row.canaryUnchanged !== false && row.allowlistViolations.length === 0)
  };
  writeJson(path.join(resultDir, "real-usage-self-test-summary.json"), summary);
  return summary;
}

function summarizeOpenCode({ stdout, verification, output, runStartMs = null, runEndMs = null }) {
  const steps = [];
  const toolCalls = [];
  let firstStepStartTs = null;
  let firstStepFinishTs = null;
  let lastStepStartTs = null;
  let lastStepFinishTs = null;
  let inputTokens = 0;
  let outputTokens = 0;
  let reasoningTokens = 0;
  let totalTokens = 0;
  if (stdout && fs.existsSync(stdout)) {
    for (const line of fs.readFileSync(stdout, "utf8").split(/\r?\n/)) {
      if (!line.trim()) continue;
      let event;
      try { event = JSON.parse(line); } catch { continue; }
      const ts = eventTimestampMs(event);
      if (event.type === "step_start") {
        if (firstStepStartTs === null) firstStepStartTs = ts;
        lastStepStartTs = ts;
      }
      if (event.type === "step_finish" && event.part?.tokens) {
        if (firstStepFinishTs === null) firstStepFinishTs = ts;
        lastStepFinishTs = ts;
        inputTokens += Number(event.part.tokens.input ?? 0);
        outputTokens += Number(event.part.tokens.output ?? 0);
        reasoningTokens += Number(event.part.tokens.reasoning ?? 0);
        totalTokens += Number(event.part.tokens.total ?? 0);
        steps.push({
          reason: event.part.reason,
          inputTokens: event.part.tokens.input ?? null,
          outputTokens: event.part.tokens.output ?? null,
          reasoningTokens: event.part.tokens.reasoning ?? null,
          totalTokens: event.part.tokens.total ?? null,
          cacheRead: event.part.tokens.cache?.read ?? null,
          cacheWrite: event.part.tokens.cache?.write ?? null,
          durationMs: lastStepStartTs !== null && ts !== null ? Number((ts - lastStepStartTs).toFixed(1)) : null
        });
      }
      if (event.type === "tool_use") {
        toolCalls.push({
          tool: event.part?.tool ?? null,
          status: event.part?.state?.status ?? null,
          title: event.part?.title ?? null,
          exit: event.part?.state?.metadata?.exit ?? null,
          command: event.part?.state?.input?.command ?? null,
          filePath: event.part?.state?.input?.filePath ?? null
        });
      }
    }
  }
  const verify = verification && fs.existsSync(verification) ? JSON.parse(fs.readFileSync(verification, "utf8")) : null;
  const startMs = numberOrNull(runStartMs);
  const endMs = numberOrNull(runEndMs);
  const activeMs = firstStepStartTs !== null && lastStepFinishTs !== null ? lastStepFinishTs - firstStepStartTs : null;
  const metrics = {
    ttftMs: null,
    ttftSource: "not-exposed-by-opencode-jsonl",
    firstStepStartMs: startMs !== null && firstStepStartTs !== null ? Number((firstStepStartTs - startMs).toFixed(1)) : null,
    firstStepFinishMs: startMs !== null && firstStepFinishTs !== null ? Number((firstStepFinishTs - startMs).toFixed(1)) : null,
    activeStepMs: activeMs === null ? null : Number(activeMs.toFixed(1)),
    wallMs: startMs !== null && endMs !== null ? Number((endMs - startMs).toFixed(1)) : null,
    inputTokens: inputTokens || null,
    outputTokens: outputTokens || null,
    reasoningTokens: reasoningTokens || null,
    totalTokens: totalTokens || null,
    outputTokensPerSecond: ratePerSecond(outputTokens || null, activeMs),
    wallOutputTokensPerSecond: startMs !== null && endMs !== null ? ratePerSecond(outputTokens || null, endMs - startMs) : null
  };
  const summary = {
    createdAt: new Date().toISOString(),
    runner: "opencode",
    stdout,
    verification,
    steps,
    toolCalls,
    metrics,
    toolCallCount: toolCalls.length,
    failedToolCalls: toolCalls.filter((call) => call.status && !["completed", "success"].includes(call.status)).length,
    passed: verify?.passed ?? null
  };
  if (output) writeJson(output, summary);
  return summary;
}

function usageFromPiEvent(event) {
  return event?.message?.usage ??
    event?.assistantMessageEvent?.partial?.usage ??
    event?.assistantMessageEvent?.message?.usage ??
    null;
}

function summarizePi({ stdout, verification, output, runStartMs = null, runEndMs = null }) {
  const toolCalls = [];
  let firstUserTs = null;
  let firstAssistantMessageTs = null;
  let firstAssistantTextTs = null;
  let lastAssistantTextTs = null;
  let inputTokens = null;
  let outputTokens = null;
  let totalTokens = null;
  let cacheReadTokens = null;
  let cacheWriteTokens = null;
  if (stdout && fs.existsSync(stdout)) {
    for (const line of fs.readFileSync(stdout, "utf8").split(/\r?\n/)) {
      if (!line.trim()) continue;
      let event;
      try { event = JSON.parse(line); } catch { continue; }
      const ts = eventTimestampMs(event);
      const role = event.message?.role ?? event.assistantMessageEvent?.message?.role ?? event.assistantMessageEvent?.partial?.role ?? null;
      if (event.type === "message_start" && role === "user" && firstUserTs === null) firstUserTs = ts;
      if (role === "assistant") {
        if (event.type === "message_start" && firstAssistantMessageTs === null) firstAssistantMessageTs = ts;
        const updateType = event.assistantMessageEvent?.type ?? "";
        if (event.type === "message_update" && (updateType === "text_start" || updateType === "text_delta")) {
          if (firstAssistantTextTs === null) firstAssistantTextTs = ts;
          lastAssistantTextTs = ts;
        }
        if (event.type === "message_update" && updateType === "toolcall_start") {
          toolCalls.push({
            type: updateType,
            name: event.assistantMessageEvent?.partial?.name ?? event.assistantMessageEvent?.message?.name ?? null,
            timestampMs: ts
          });
        }
      }
      const usage = usageFromPiEvent(event);
      if (usage) {
        const current = {
          inputTokens: firstNumber(usage.input, usage.input_tokens, usage.prompt_tokens),
          outputTokens: firstNumber(usage.output, usage.output_tokens, usage.completion_tokens),
          totalTokens: firstNumber(usage.totalTokens, usage.total_tokens),
          cacheReadTokens: firstNumber(usage.cacheRead, usage.cache?.read),
          cacheWriteTokens: firstNumber(usage.cacheWrite, usage.cache?.write)
        };
        for (const [key, value] of Object.entries(current)) {
          if (value === null || value === 0) continue;
          if (key === "inputTokens") inputTokens = Math.max(inputTokens ?? 0, value);
          if (key === "outputTokens") outputTokens = Math.max(outputTokens ?? 0, value);
          if (key === "totalTokens") totalTokens = Math.max(totalTokens ?? 0, value);
          if (key === "cacheReadTokens") cacheReadTokens = Math.max(cacheReadTokens ?? 0, value);
          if (key === "cacheWriteTokens") cacheWriteTokens = Math.max(cacheWriteTokens ?? 0, value);
        }
      }
    }
  }
  const verify = verification && fs.existsSync(verification) ? JSON.parse(fs.readFileSync(verification, "utf8")) : null;
  const startMs = numberOrNull(runStartMs);
  const endMs = numberOrNull(runEndMs);
  const generationMs = firstAssistantTextTs !== null && lastAssistantTextTs !== null ? lastAssistantTextTs - firstAssistantTextTs : null;
  const metrics = {
    ttftMs: firstUserTs !== null && firstAssistantTextTs !== null ? Number((firstAssistantTextTs - firstUserTs).toFixed(1)) : null,
    ttftSource: firstUserTs !== null && firstAssistantTextTs !== null ? "first-pi-message-update-text" : "not-observed",
    firstAssistantMessageMs: firstUserTs !== null && firstAssistantMessageTs !== null ? Number((firstAssistantMessageTs - firstUserTs).toFixed(1)) : null,
    wallMs: startMs !== null && endMs !== null ? Number((endMs - startMs).toFixed(1)) : null,
    inputTokens,
    outputTokens,
    totalTokens,
    cacheReadTokens,
    cacheWriteTokens,
    usageSource: [inputTokens, outputTokens, totalTokens].some((value) => value !== null) ? "pi-jsonl-usage" : null,
    outputTokensPerSecond: ratePerSecond(outputTokens, generationMs),
    wallOutputTokensPerSecond: startMs !== null && endMs !== null ? ratePerSecond(outputTokens, endMs - startMs) : null
  };
  const summary = {
    createdAt: new Date().toISOString(),
    runner: "pi-docker",
    stdout,
    verification,
    toolCalls,
    metrics,
    toolCallCount: toolCalls.length,
    failedToolCalls: null,
    passed: verify?.passed ?? null
  };
  if (output) writeJson(output, summary);
  return summary;
}

function usage() {
  return `Usage:
  node scripts/real-usage-suite.mjs list
  node scripts/real-usage-suite.mjs prepare --task backend-api [--run-id ID]
  node scripts/real-usage-suite.mjs agent-prompt --task backend-api --workspace PATH [--output PATH]
  node scripts/real-usage-suite.mjs verify --task backend-api --workspace PATH --manifest-before PATH [--output PATH]
  node scripts/real-usage-suite.mjs apply-golden --task backend-api --workspace PATH
  node scripts/real-usage-suite.mjs self-test [--tasks all]
  node scripts/real-usage-suite.mjs run-api --task backend-api --base-url URL --model MODEL [--reasoning-effort none] [--prompt-extra-file PATH]
  node scripts/real-usage-suite.mjs summarize-opencode --stdout PATH --verification PATH [--output PATH]
  node scripts/real-usage-suite.mjs summarize-pi --stdout PATH --verification PATH [--output PATH]`;
}

async function main() {
  const command = process.argv[2];
  const options = parseOptions(process.argv.slice(3));
  let result;
  if (!command || command === "--help" || command === "help") {
    process.stdout.write(`${usage()}\n`);
    return;
  }
  if (command === "list") {
    result = { version: spec.version, tasks: spec.tasks.map(({ id, title, class: cls, rationale }) => ({ id, title, class: cls, rationale })) };
  } else if (command === "prepare") {
    result = prepareTask({ taskId: options.task, runId: options["run-id"] ?? stamp(), resultDir: options["result-dir"] ?? "" });
  } else if (command === "agent-prompt") {
    const task = ensureTask(String(options.task ?? ""));
    const workspace = path.resolve(String(options.workspace ?? ""));
    const prompt = buildAgentPrompt({ task, workspace });
    if (options.output) {
      fs.mkdirSync(path.dirname(path.resolve(String(options.output))), { recursive: true });
      fs.writeFileSync(path.resolve(String(options.output)), prompt, "utf8");
    }
    result = { task: task.id, workspace, output: options.output ? path.resolve(String(options.output)) : null, prompt };
  } else if (command === "verify") {
    result = verifyWorkspace({ taskId: options.task, workspace: options.workspace, manifestBefore: options["manifest-before"], output: options.output });
  } else if (command === "apply-golden") {
    applyGolden({ taskId: options.task, workspace: options.workspace });
    result = { task: options.task, workspace: path.resolve(options.workspace), applied: true };
  } else if (command === "self-test") {
    result = await selfTest(options);
  } else if (command === "run-api") {
    result = await runApi(options);
  } else if (command === "summarize-opencode") {
    result = summarizeOpenCode({
      stdout: options.stdout,
      verification: options.verification,
      output: options.output,
      runStartMs: options["run-start-ms"] ?? null,
      runEndMs: options["run-end-ms"] ?? null
    });
  } else if (command === "summarize-pi") {
    result = summarizePi({
      stdout: options.stdout,
      verification: options.verification,
      output: options.output,
      runStartMs: options["run-start-ms"] ?? null,
      runEndMs: options["run-end-ms"] ?? null
    });
  } else {
    throw new Error(`Unknown command: ${command}\n${usage()}`);
  }
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (result && result.passed === false) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exit(1);
});
