#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { performance } from "node:perf_hooks";

function parseArgs(argv) {
  const out = {
    baseUrl: "http://127.0.0.1:11434/v1",
    model: "qwen3-coder:30b",
    label: "",
    prompt: "",
    promptFile: "",
    output: "",
    maxTokens: 512,
    contextLength: 4096,
    temperature: 0,
    timeoutMs: 300000,
    reps: 1,
    reasoningEffort: ""
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--base-url") out.baseUrl = next, i += 1;
    else if (arg === "--model") out.model = next, i += 1;
    else if (arg === "--label") out.label = next, i += 1;
    else if (arg === "--prompt") out.prompt = next, i += 1;
    else if (arg === "--prompt-file") out.promptFile = next, i += 1;
    else if (arg === "--output") out.output = next, i += 1;
    else if (arg === "--max-tokens") out.maxTokens = Number(next), i += 1;
    else if (arg === "--context-length") out.contextLength = Number(next), i += 1;
    else if (arg === "--temperature") out.temperature = Number(next), i += 1;
    else if (arg === "--timeout-ms") out.timeoutMs = Number(next), i += 1;
    else if (arg === "--reps") out.reps = Number(next), i += 1;
    else if (arg === "--reasoning-effort") out.reasoningEffort = next, i += 1;
    else if (arg === "--help" || arg === "-h") out.help = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return out;
}

function usage() {
  return `Usage:
  node scripts/probe-openai-throughput.mjs --base-url URL --model MODEL [--label NAME] [--reps N] [--output PATH]

Runs a streaming OpenAI-compatible chat completion and records TTFT/TPS metrics.
`;
}

function defaultPrompt() {
  return [
    "Write a concise engineering analysis of why a local inference endpoint can show GPU placement yet still be slow.",
    "Use numbered points, include concrete diagnostic commands, and end with a short recommendation.",
    "Produce enough detail to require a few hundred output tokens, but do not use markdown tables."
  ].join("\n");
}

function percentile(values, p) {
  const nums = values.filter((value) => Number.isFinite(value)).sort((a, b) => a - b);
  if (nums.length === 0) return null;
  const index = Math.min(nums.length - 1, Math.max(0, Math.ceil((p / 100) * nums.length) - 1));
  return nums[index];
}

function avg(values) {
  const nums = values.filter((value) => Number.isFinite(value));
  if (nums.length === 0) return null;
  return nums.reduce((sum, value) => sum + value, 0) / nums.length;
}

function round(value, places = 2) {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return null;
  return Number(Number(value).toFixed(places));
}

function deriveMetrics({ firstByteMs, firstContentMs, wallMs, usage, output }) {
  const outputTokens = usage?.completion_tokens ?? usage?.output_tokens ?? null;
  const inputTokens = usage?.prompt_tokens ?? usage?.input_tokens ?? null;
  const totalTokens = usage?.total_tokens ?? null;
  const generationMs = firstContentMs === null ? wallMs : Math.max(0, wallMs - firstContentMs);
  const outputTokensPerSecond = Number.isFinite(outputTokens) && generationMs > 0
    ? (outputTokens / generationMs) * 1000
    : null;
  const wallOutputTokensPerSecond = Number.isFinite(outputTokens) && wallMs > 0
    ? (outputTokens / wallMs) * 1000
    : null;
  return {
    firstByteMs: round(firstByteMs, 1),
    ttftMs: round(firstContentMs, 1),
    wallMs: round(wallMs, 1),
    inputTokens,
    outputTokens,
    totalTokens,
    outputChars: output.length,
    outputTokensPerSecond: round(outputTokensPerSecond, 2),
    wallOutputTokensPerSecond: round(wallOutputTokensPerSecond, 2)
  };
}

async function streamOnce(args, prompt, rep) {
  const started = performance.now();
  let firstByteMs = null;
  let firstContentMs = null;
  let output = "";
  let usage = null;
  let streamEvents = 0;
  let streamChunks = 0;
  const body = {
    model: args.model,
    stream: true,
    stream_options: { include_usage: true },
    temperature: args.temperature,
    max_tokens: args.maxTokens,
    messages: [
      { role: "system", content: "You are a concise, technically precise engineering assistant." },
      { role: "user", content: prompt }
    ]
  };
  if (args.reasoningEffort) body.reasoning_effort = args.reasoningEffort;
  if (args.contextLength > 0) body.options = { num_ctx: args.contextLength };

  const response = await fetch(`${args.baseUrl.replace(/\/+$/, "")}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer local" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(args.timeoutMs)
  });
  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`HTTP ${response.status}: ${text.slice(0, 1200)}`);
  }
  if (!response.body) throw new Error("Response body is not streamable");

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    streamChunks += 1;
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
      try {
        parsed = JSON.parse(data);
      } catch {
        continue;
      }
      streamEvents += 1;
      if (parsed.usage) usage = parsed.usage;
      const content = parsed.choices?.[0]?.delta?.content ?? "";
      if (content) {
        if (firstContentMs === null) firstContentMs = performance.now() - started;
        output += content;
      }
    }
  }
  const wallMs = performance.now() - started;
  return {
    rep,
    createdAt: new Date().toISOString(),
    metrics: deriveMetrics({ firstByteMs, firstContentMs, wallMs, usage, output }),
    usage,
    streamEvents,
    streamChunks,
    outputPreview: output.slice(0, 1000)
  };
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  process.stdout.write(usage());
  process.exit(0);
}
const prompt = args.promptFile
  ? fs.readFileSync(args.promptFile, "utf8")
  : (args.prompt || defaultPrompt());

const runs = [];
for (let rep = 1; rep <= args.reps; rep += 1) {
  runs.push(await streamOnce(args, prompt, rep));
}

const summary = {
  createdAt: new Date().toISOString(),
  label: args.label,
  baseUrl: args.baseUrl,
  model: args.model,
  request: {
    maxTokens: args.maxTokens,
    contextLength: args.contextLength,
    temperature: args.temperature,
    reps: args.reps,
    reasoningEffort: args.reasoningEffort || null,
    promptChars: prompt.length
  },
  aggregate: {
    avgTtftMs: round(avg(runs.map((run) => run.metrics.ttftMs)), 1),
    p50TtftMs: round(percentile(runs.map((run) => run.metrics.ttftMs), 50), 1),
    avgOutputTokensPerSecond: round(avg(runs.map((run) => run.metrics.outputTokensPerSecond)), 2),
    p50OutputTokensPerSecond: round(percentile(runs.map((run) => run.metrics.outputTokensPerSecond), 50), 2),
    avgWallOutputTokensPerSecond: round(avg(runs.map((run) => run.metrics.wallOutputTokensPerSecond)), 2),
    p50WallOutputTokensPerSecond: round(percentile(runs.map((run) => run.metrics.wallOutputTokensPerSecond), 50), 2),
    avgOutputTokens: round(avg(runs.map((run) => run.metrics.outputTokens)), 1)
  },
  runs
};

if (args.output) {
  fs.mkdirSync(path.dirname(path.resolve(args.output)), { recursive: true });
  fs.writeFileSync(args.output, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
}
process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
