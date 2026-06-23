#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { performance } from "node:perf_hooks";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const benchRoot = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(benchRoot, "..", "..");

const specs = {
  "js-window": {
    request: "Fix the event window counter so both the start and end boundaries are included.",
    inspect: ["README.md", "src/windowCounter.mjs", "tools/test.mjs"],
    editable: ["src/windowCounter.mjs"],
    verifier: { command: process.execPath, args: ["tools/test.mjs"] },
  },
  "browser-style": {
    request: "Fix the browser-facing filter behavior so matching is case-insensitive and the empty state is correct.",
    hint: "DOM hidden semantics: element.hidden = true hides the element; element.hidden = false shows it. In this fixture, the existing empty-state expression empty.hidden = visible !== 0 is correct because it shows the empty message only when visible is 0; preserve that behavior while fixing matching.",
    inspect: ["README.md", "index.html", "app.js", "tools/test.mjs"],
    editable: ["app.js", "index.html"],
    protectedText: {
      "app.js": ["empty.hidden = visible !== 0;"],
    },
    verifier: { command: process.execPath, args: ["tools/test.mjs"] },
  },
};

function parseArgs(argv) {
  const args = {
    baseUrl: "http://127.0.0.1:8080/v1",
    model: "qwen/qwen3-coder-30b",
    task: "js-window",
    maxTokens: 2048,
    maxAttempts: 2,
    temperature: 0,
    reasoningEffort: "",
    timeoutMs: 300000,
    runId: `controlled-${timestamp()}`,
    outputDir: "",
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      if (i >= argv.length) throw new Error(`Missing value for ${arg}`);
      return argv[i];
    };
    if (arg === "--base-url") args.baseUrl = next();
    else if (arg === "--model") args.model = next();
    else if (arg === "--task") args.task = next();
    else if (arg === "--max-tokens") args.maxTokens = Number(next());
    else if (arg === "--max-attempts") args.maxAttempts = Number(next());
    else if (arg === "--temperature") args.temperature = Number(next());
    else if (arg === "--reasoning-effort") args.reasoningEffort = next();
    else if (arg === "--timeout-ms") args.timeoutMs = Number(next());
    else if (arg === "--run-id") args.runId = next();
    else if (arg === "--output-dir") args.outputDir = next();
    else if (arg === "--help") {
      console.log(`Usage: node run-controlled-edit-agent.mjs --base-url http://127.0.0.1:8080/v1 --model MODEL [options]

Options:
  --task js-window|browser-style
  --max-tokens N
  --max-attempts N
  --temperature N
  --reasoning-effort VALUE
  --timeout-ms N
  --run-id ID
  --output-dir PATH`);
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function sha1(file) {
  return crypto.createHash("sha1").update(fs.readFileSync(file)).digest("hex");
}

function listFiles(root, base = root) {
  const out = {};
  if (!fs.existsSync(root)) return out;
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) {
      Object.assign(out, listFiles(full, base));
    } else {
      const rel = path.relative(base, full).replace(/\\/g, "/");
      const stat = fs.statSync(full);
      out[rel] = { size: stat.size, mtimeMs: Math.round(stat.mtimeMs), sha1: sha1(full) };
    }
  }
  return out;
}

function changedFiles(before, after) {
  const changed = [];
  for (const [file, meta] of Object.entries(after)) {
    if (!before[file] || before[file].sha1 !== meta.sha1) changed.push(file);
  }
  for (const file of Object.keys(before)) {
    if (!after[file]) changed.push(`${file} (deleted)`);
  }
  return changed.sort();
}

function readFixtureFiles(fixture, files) {
  return files.map((rel) => {
    const full = path.join(fixture, rel);
    const text = fs.readFileSync(full, "utf8");
    return `## ${rel}\n\n\`\`\`\n${text}\n\`\`\``;
  }).join("\n\n");
}

function buildPrompt({ task, spec, fixture }) {
  const selected = readFixtureFiles(fixture, spec.inspect);
  return `You are a local coding edit agent running inside a benchmark harness.

Task: ${spec.request}
${spec.hint ? `\nImportant runtime hint: ${spec.hint}\n` : ""}
${spec.protectedText ? `\nProtected invariants that must remain present after your edit:\n${Object.entries(spec.protectedText).flatMap(([file, values]) => values.map((value) => `- ${file}: ${value}`)).join("\n")}\n` : ""}

You may modify only these relative files:
${spec.editable.map((file) => `- ${file}`).join("\n")}

Return only a single JSON object with this shape:
{"replacements":[{"path":"relative/path","find":"exact text to replace","replace":"replacement text"}],"files":[],"notes":"short explanation"}

Rules:
- The JSON must parse with JSON.parse.
- Do not wrap the JSON in Markdown.
- Prefer exact replacements for small edits.
- Use full file replacement content in files[] only if an exact replacement is not practical.
- Do not include files that do not need to change.
- Do not modify tests unless tests are explicitly in the allowlist.
- Keep all paths relative to the fixture root.

Fixture root:
${fixture}

Relevant files:

${selected}
`;
}

function buildRepairPrompt({ task, spec, fixture, previous }) {
  const editableState = readFixtureFiles(fixture, spec.editable);
  return `${buildPrompt({ task, spec, fixture })}

The previous attempt did not pass.

Previous apply error:
\`\`\`
${previous.applyError ?? ""}
\`\`\`

Previous verification:
\`\`\`
exitCode=${previous.verification?.exitCode}
stdout=${previous.verification?.stdout ?? ""}
stderr=${previous.verification?.stderr ?? ""}
\`\`\`

Current editable file state after the previous attempt:

${editableState}

Return a corrected JSON object using the same schema.`;
}

async function streamChat({ baseUrl, model, prompt, maxTokens, temperature, reasoningEffort, timeoutMs }) {
  const startedAt = performance.now();
  let firstByteMs = null;
  let firstContentMs = null;
  let output = "";
  let usage = null;
  let rawChunks = 0;
  let events = 0;

  const body = {
    model,
    temperature,
    max_tokens: maxTokens,
    stream: true,
    stream_options: { include_usage: true },
    messages: [
      { role: "system", content: "You produce only machine-parseable JSON for safe file edits." },
      { role: "user", content: prompt },
    ],
  };
  if (reasoningEffort) {
    body.reasoning_effort = reasoningEffort;
  }

  const response = await fetch(`${baseUrl.replace(/\/+$/, "")}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer local" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`HTTP ${response.status}: ${text.slice(0, 2000)}`);
  }
  if (!response.body) throw new Error("Response body is not streamable");

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    rawChunks += 1;
    if (firstByteMs === null) firstByteMs = performance.now() - startedAt;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data:")) continue;
      const data = trimmed.slice(5).trim();
      if (!data || data === "[DONE]") continue;
      let parsed;
      try {
        parsed = JSON.parse(data);
      } catch {
        continue;
      }
      events += 1;
      if (parsed.usage) usage = parsed.usage;
      const content = parsed.choices?.[0]?.delta?.content ?? "";
      if (content) {
        if (firstContentMs === null) firstContentMs = performance.now() - startedAt;
        output += content;
      }
    }
  }

  const wallMs = performance.now() - startedAt;
  return {
    output,
    metrics: {
      firstByteMs: firstByteMs === null ? null : Number(firstByteMs.toFixed(1)),
      firstContentMs: firstContentMs === null ? null : Number(firstContentMs.toFixed(1)),
      wallMs: Number(wallMs.toFixed(1)),
      usage,
      rawChunks,
      events,
    },
  };
}

function parseJsonObject(text) {
  const stripped = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  try {
    return JSON.parse(stripped);
  } catch {
    const start = stripped.indexOf("{");
    const end = stripped.lastIndexOf("}");
    if (start >= 0 && end > start) {
      return JSON.parse(stripped.slice(start, end + 1));
    }
    throw new Error("Model output did not contain a parseable JSON object");
  }
}

function applyEdits({ fixture, spec, editJson }) {
  const editable = new Set(spec.editable);
  const applied = [];
  if (Array.isArray(editJson.replacements)) {
    for (const replacement of editJson.replacements) {
      const rel = validateRelativePath(replacement.path, editable);
      if (typeof replacement.find !== "string" || replacement.find.length === 0) {
        throw new Error(`Replacement for ${rel} is missing non-empty find text`);
      }
      if (typeof replacement.replace !== "string") {
        throw new Error(`Replacement for ${rel} is missing string replace text`);
      }
      const full = resolveFixturePath(fixture, rel);
      const original = fs.readFileSync(full, "utf8");
      let count = original.split(replacement.find).length - 1;
      let nextText = null;
      if (count === 1) {
        nextText = original.replace(replacement.find, replacement.replace);
      } else if (replacement.find.includes("\n")) {
        const normalizedOriginal = original.replace(/\r\n/g, "\n");
        const normalizedFind = replacement.find.replace(/\r\n/g, "\n");
        const normalizedReplace = replacement.replace.replace(/\r\n/g, "\n");
        count = normalizedOriginal.split(normalizedFind).length - 1;
        if (count === 1) {
          nextText = normalizedOriginal.replace(normalizedFind, normalizedReplace);
        }
      }
      if (nextText === null) {
        throw new Error(`Replacement for ${rel} matched ${count} times; expected exactly 1`);
      }
      validateProtectedText({ spec, rel, content: nextText });
      fs.writeFileSync(full, nextText, "utf8");
      applied.push(rel);
    }
  }
  if (!Array.isArray(editJson.files)) {
    if (applied.length > 0) return applied;
    throw new Error("Edit JSON is missing files[] or replacements[]");
  }
  for (const file of editJson.files) {
    const rel = validateRelativePath(file.path, editable);
    if (typeof file.content !== "string") {
      throw new Error(`Edit for ${rel} is missing string content`);
    }
    validateProtectedText({ spec, rel, content: file.content });
    const full = resolveFixturePath(fixture, rel);
    fs.writeFileSync(full, file.content, "utf8");
    applied.push(rel);
  }
  return applied;
}

function validateProtectedText({ spec, rel, content }) {
  const required = spec.protectedText?.[rel] ?? [];
  for (const text of required) {
    if (!content.includes(text)) {
      throw new Error(`Edit for ${rel} removed protected text: ${text}`);
    }
  }
}

function validateRelativePath(value, editable) {
  const rel = String(value ?? "").replace(/\\/g, "/");
  if (!editable.has(rel)) {
    throw new Error(`Refusing edit outside allowlist: ${rel}`);
  }
  if (path.isAbsolute(rel) || rel.includes("..")) {
    throw new Error(`Refusing unsafe relative path: ${rel}`);
  }
  return rel;
}

function resolveFixturePath(fixture, rel) {
  const full = path.resolve(fixture, rel);
  if (!full.startsWith(path.resolve(fixture) + path.sep)) {
    throw new Error(`Resolved path escapes fixture: ${rel}`);
  }
  return full;
}

function runVerifier({ fixture, spec }) {
  const started = Date.now();
  const child = spawnSync(spec.verifier.command, spec.verifier.args, {
    cwd: fixture,
    encoding: "utf8",
    timeout: 120000,
    env: { ...process.env },
  });
  return {
    command: [spec.verifier.command, ...spec.verifier.args].join(" "),
    exitCode: child.status,
    elapsedMs: Date.now() - started,
    stdout: child.stdout,
    stderr: child.stderr,
    timedOut: Boolean(child.error && child.error.code === "ETIMEDOUT"),
  };
}

async function main() {
  const args = parseArgs(process.argv);
  const spec = specs[args.task];
  if (!spec) throw new Error(`Unknown task: ${args.task}`);

  const template = path.join(repoRoot, "benchmarks", "opencode-agent-benchmark", "templates", args.task);
  if (!fs.existsSync(template)) throw new Error(`Missing template: ${template}`);

  const fixture = path.join(repoRoot, "benchmarks", "opencode-agent-benchmark", "fixtures", "work", args.runId, args.task);
  fs.rmSync(fixture, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(fixture), { recursive: true });
  fs.cpSync(template, fixture, { recursive: true });

  const outputDir = args.outputDir
    ? path.resolve(args.outputDir)
    : path.join(benchRoot, "results", `${timestamp()}-${args.runId}`);
  fs.mkdirSync(outputDir, { recursive: true });

  const before = listFiles(fixture);
  fs.writeFileSync(path.join(outputDir, `${args.task}-manifest-before.json`), JSON.stringify(before, null, 2) + "\n", "utf8");

  const attempts = [];
  let previous = null;
  let final = null;
  for (let attempt = 1; attempt <= args.maxAttempts; attempt += 1) {
    const prompt = previous
      ? buildRepairPrompt({ task: args.task, spec, fixture, previous })
      : buildPrompt({ task: args.task, spec, fixture });
    const attemptLabel = `${args.task}-attempt${String(attempt).padStart(2, "0")}`;
    fs.writeFileSync(path.join(outputDir, `${attemptLabel}-prompt.md`), prompt, "utf8");

    const { output, metrics } = await streamChat({
      baseUrl: args.baseUrl,
      model: args.model,
      prompt,
      maxTokens: args.maxTokens,
      temperature: args.temperature,
      reasoningEffort: args.reasoningEffort,
      timeoutMs: args.timeoutMs,
    });
    fs.writeFileSync(path.join(outputDir, `${attemptLabel}-model-output.txt`), output, "utf8");

    let editJson = null;
    let applied = [];
    let applyError = null;
    try {
      editJson = parseJsonObject(output);
      applied = applyEdits({ fixture, spec, editJson });
    } catch (error) {
      applyError = error.stack ?? error.message;
    }

    const after = listFiles(fixture);
    const verification = runVerifier({ fixture, spec });
    const attemptResult = {
      attempt,
      promptChars: prompt.length,
      metrics,
      outputChars: output.length,
      editJson,
      applied,
      applyError,
      modifiedFiles: changedFiles(before, after),
      verification,
      passed: !applyError && applied.length > 0 && verification.exitCode === 0 && !verification.timedOut,
    };
    attempts.push(attemptResult);
    previous = attemptResult;
    final = attemptResult;
    fs.writeFileSync(path.join(outputDir, `${attemptLabel}-result.json`), JSON.stringify(attemptResult, null, 2) + "\n", "utf8");
    if (attemptResult.passed) {
      break;
    }
  }

  const after = listFiles(fixture);
  const result = {
    created: new Date().toISOString(),
    runner: "controlled-edit-agent",
    task: args.task,
    model: args.model,
    baseUrl: args.baseUrl,
    fixture,
    outputDir,
    maxTokens: args.maxTokens,
    maxAttempts: args.maxAttempts,
    temperature: args.temperature,
    reasoningEffort: args.reasoningEffort || null,
    attempts,
    metrics: final?.metrics ?? null,
    editJson: final?.editJson ?? null,
    applied: final?.applied ?? [],
    applyError: final ? final.applyError : "no attempt was run",
    modifiedFiles: changedFiles(before, after),
    verification: final?.verification ?? null,
    passed: Boolean(final?.passed),
  };

  fs.writeFileSync(path.join(outputDir, `${args.task}-result.json`), JSON.stringify(result, null, 2) + "\n", "utf8");
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exit(1);
});
