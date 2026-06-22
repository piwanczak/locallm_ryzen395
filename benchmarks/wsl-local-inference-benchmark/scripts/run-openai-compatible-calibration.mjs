#!/usr/bin/env node
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { performance } from "node:perf_hooks";

function parseArgs(argv) {
  const args = {
    baseUrl: "http://127.0.0.1:8080/v1",
    model: "",
    prompt: "Write a concise JavaScript function that counts values inside a sliding window.",
    promptFile: "",
    maxTokens: 256,
    temperature: 0,
    concurrency: 1,
    timeoutMs: 300000,
    output: "",
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
    else if (arg === "--prompt") args.prompt = next();
    else if (arg === "--prompt-file") args.promptFile = next();
    else if (arg === "--max-tokens") args.maxTokens = Number(next());
    else if (arg === "--temperature") args.temperature = Number(next());
    else if (arg === "--concurrency") args.concurrency = Number(next());
    else if (arg === "--timeout-ms") args.timeoutMs = Number(next());
    else if (arg === "--output") args.output = next();
    else if (arg === "--help") {
      console.log(`Usage: node run-openai-compatible-calibration.mjs --base-url http://127.0.0.1:8080/v1 --model MODEL [options]

Options:
  --prompt TEXT
  --prompt-file PATH
  --max-tokens N
  --temperature N
  --concurrency N
  --timeout-ms N
  --output PATH`);
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function normalizeBaseUrl(baseUrl) {
  return baseUrl.replace(/\/+$/, "");
}

function estimateTokens(text) {
  return Math.max(1, Math.ceil(Buffer.byteLength(text, "utf8") / 3.7));
}

async function runOne({ baseUrl, model, prompt, maxTokens, temperature, timeoutMs, index }) {
  const body = {
    model,
    temperature,
    max_tokens: maxTokens,
    stream: true,
    stream_options: { include_usage: true },
    messages: [
      { role: "system", content: "You are a concise coding assistant. Return only the requested answer." },
      { role: "user", content: prompt },
    ],
  };

  const startedAt = performance.now();
  let firstByteMs = null;
  let firstContentMs = null;
  let usage = null;
  let output = "";
  let rawChunks = 0;
  let events = 0;

  const response = await fetch(`${normalizeBaseUrl(baseUrl)}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer local" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "");
    throw new Error(`HTTP ${response.status}: ${errorText.slice(0, 1000)}`);
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
      events += 1;
      let parsed;
      try {
        parsed = JSON.parse(data);
      } catch {
        continue;
      }
      if (parsed.usage) usage = parsed.usage;
      const content = parsed.choices?.[0]?.delta?.content ?? "";
      if (content) {
        if (firstContentMs === null) firstContentMs = performance.now() - startedAt;
        output += content;
      }
    }
  }

  const wallMs = performance.now() - startedAt;
  const completionTokens = usage?.completion_tokens ?? estimateTokens(output);
  const decodeWindowSeconds = Math.max(0.001, (wallMs - (firstContentMs ?? firstByteMs ?? wallMs)) / 1000);

  return {
    index,
    ok: true,
    firstByteMs: Number(firstByteMs?.toFixed(1) ?? null),
    firstContentMs: Number(firstContentMs?.toFixed(1) ?? null),
    wallMs: Number(wallMs.toFixed(1)),
    outputChars: output.length,
    outputTokenEstimate: completionTokens,
    decodeTokPerSecEstimate: Number((completionTokens / decodeWindowSeconds).toFixed(2)),
    usage,
    rawChunks,
    events,
    outputPreview: output.slice(0, 500),
  };
}

async function main() {
  const args = parseArgs(process.argv);
  const prompt = args.promptFile ? await readFile(args.promptFile, "utf8") : args.prompt;
  if (!args.model) throw new Error("--model is required for most OpenAI-compatible servers");

  const started = new Date();
  const runInputs = Array.from({ length: args.concurrency }, (_, index) => ({
    ...args,
    prompt,
    index: index + 1,
  }));

  const settled = await Promise.allSettled(runInputs.map((input) => runOne(input)));
  const results = settled.map((item, index) => {
    if (item.status === "fulfilled") return item.value;
    return {
      index: index + 1,
      ok: false,
      error: item.reason?.stack ?? item.reason?.message ?? String(item.reason),
    };
  });

  const successful = results.filter((result) => result.ok);
  const summary = {
    created: started.toISOString(),
    baseUrl: args.baseUrl,
    model: args.model,
    promptChars: prompt.length,
    promptTokenEstimate: estimateTokens(prompt),
    maxTokens: args.maxTokens,
    temperature: args.temperature,
    concurrency: args.concurrency,
    ok: successful.length === results.length,
    successful: successful.length,
    failed: results.length - successful.length,
    firstByteMsMin: successful.length ? Math.min(...successful.map((r) => r.firstByteMs ?? Infinity)) : null,
    firstContentMsMin: successful.length ? Math.min(...successful.map((r) => r.firstContentMs ?? Infinity)) : null,
    decodeTokPerSecAggregateEstimate: Number(successful.reduce((sum, r) => sum + (r.decodeTokPerSecEstimate ?? 0), 0).toFixed(2)),
    results,
  };

  const json = `${JSON.stringify(summary, null, 2)}\n`;
  if (args.output) {
    const outputPath = resolve(args.output);
    await mkdir(dirname(outputPath), { recursive: true });
    await writeFile(outputPath, json, "utf8");
  }
  process.stdout.write(json);
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exit(1);
});
