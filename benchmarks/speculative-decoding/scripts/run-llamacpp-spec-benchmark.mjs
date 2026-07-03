import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(__filename);
const benchDir = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(benchDir, "..", "..");

function parseArgs(argv) {
  const args = {
    reps: 3,
    tokens: 128,
    context: 1024,
    draftN: 3,
    promptFile: path.join(benchDir, "prompts", "coding-add.txt"),
    llamaCli: path.join(repoRoot, "downloads", "llama-vulkan", "b9728-vulkan", "llama-cli.exe"),
    model: path.join(repoRoot, "downloads", "speculative-qwen25coder", "qwen2.5-coder-7b-q8_0.gguf"),
    draft: path.join(repoRoot, "downloads", "speculative-qwen25coder", "qwen2.5-coder-0.5b-q8_0.gguf"),
    runName: timestamp(),
  };

  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    const next = argv[i + 1];
    if (key === "--reps") args.reps = Number(next), i += 1;
    else if (key === "--tokens") args.tokens = Number(next), i += 1;
    else if (key === "--context") args.context = Number(next), i += 1;
    else if (key === "--draft-n") args.draftN = Number(next), i += 1;
    else if (key === "--prompt-file") args.promptFile = path.resolve(next), i += 1;
    else if (key === "--llama-cli") args.llamaCli = path.resolve(next), i += 1;
    else if (key === "--model") args.model = path.resolve(next), i += 1;
    else if (key === "--draft") args.draft = path.resolve(next), i += 1;
    else if (key === "--run-name") args.runName = next, i += 1;
    else if (key === "--help" || key === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${key}`);
    }
  }

  for (const numericKey of ["reps", "tokens", "context", "draftN"]) {
    if (!Number.isFinite(args[numericKey]) || args[numericKey] <= 0) {
      throw new Error(`Invalid ${numericKey}: ${args[numericKey]}`);
    }
  }

  return args;
}

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}-qwen25coder-spec`;
}

function printHelp() {
  console.log(`Usage:
node benchmarks/speculative-decoding/scripts/run-llamacpp-spec-benchmark.mjs [options]

Options:
  --reps N           repetitions per variant, default 3
  --tokens N         generated token cap, default 128
  --context N        context length, default 1024
  --draft-n N        draft tokens for draft-simple, default 3
  --prompt-file P    prompt text file
  --llama-cli P      llama-cli executable
  --model P          target GGUF
  --draft P          draft GGUF
  --run-name NAME    result directory name
`);
}

function mustExist(label, filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${label} does not exist: ${filePath}`);
  }
}

function runOne({ variant, rep, args, prompt, resultDir }) {
  const seed = 42;
  const commonArgs = [
    "-m", args.model,
    "-p", prompt,
    "-n", String(args.tokens),
    "-c", String(args.context),
    "-ngl", "all",
    "-fa", "on",
    "--temp", "0",
    "--seed", String(seed),
    "--no-display-prompt",
    "--no-warmup",
  ];

  const cliArgs = variant === "draft"
    ? [
        "-m", args.model,
        "--model-draft", args.draft,
        "--spec-type", "draft-simple",
        "--spec-draft-n-max", String(args.draftN),
        "--spec-draft-ngl", "all",
        "-p", prompt,
        "-n", String(args.tokens),
        "-c", String(args.context),
        "-ngl", "all",
        "-fa", "on",
        "--temp", "0",
        "--seed", String(seed),
        "--no-display-prompt",
        "--no-warmup",
      ]
    : commonArgs;

  const started = Date.now();
  const proc = spawnSync(args.llamaCli, cliArgs, {
    cwd: repoRoot,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  const elapsedMs = Date.now() - started;

  const prefix = `${variant}-rep${rep}`;
  fs.writeFileSync(path.join(resultDir, `${prefix}.stdout.txt`), proc.stdout ?? "");
  fs.writeFileSync(path.join(resultDir, `${prefix}.stderr.txt`), proc.stderr ?? "");

  const combined = `${proc.stdout ?? ""}\n${proc.stderr ?? ""}`;
  const parsed = parseTiming(combined);
  return {
    variant,
    rep,
    exitCode: proc.status,
    signal: proc.signal,
    elapsedMs,
    promptTps: parsed.promptTps,
    generationTps: parsed.generationTps,
    timingLine: parsed.timingLine,
  };
}

function parseTiming(output) {
  const matches = [...output.matchAll(/\[ Prompt:\s*([0-9.]+)\s*t\/s\s*\|\s*Generation:\s*([0-9.]+)\s*t\/s\s*\]/g)];
  if (matches.length === 0) {
    return { promptTps: null, generationTps: null, timingLine: null };
  }
  const match = matches[matches.length - 1];
  return {
    promptTps: Number(match[1]),
    generationTps: Number(match[2]),
    timingLine: match[0],
  };
}

function median(values) {
  const sorted = values.filter((v) => Number.isFinite(v)).sort((a, b) => a - b);
  if (sorted.length === 0) return null;
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

function summarize(results) {
  const byVariant = {};
  for (const variant of ["base", "draft"]) {
    const rows = results.filter((r) => r.variant === variant);
    byVariant[variant] = {
      runs: rows.length,
      failures: rows.filter((r) => r.exitCode !== 0 || !Number.isFinite(r.generationTps)).length,
      medianPromptTps: median(rows.map((r) => r.promptTps)),
      medianGenerationTps: median(rows.map((r) => r.generationTps)),
      medianElapsedMs: median(rows.map((r) => r.elapsedMs)),
    };
  }
  const base = byVariant.base.medianGenerationTps;
  const draft = byVariant.draft.medianGenerationTps;
  return {
    byVariant,
    generationSpeedup: Number.isFinite(base) && Number.isFinite(draft) ? draft / base : null,
  };
}

function writeMarkdown({ args, prompt, results, summary, resultDir }) {
  const lines = [];
  lines.push(`# Speculative Decoding Run ${args.runName}`);
  lines.push("");
  lines.push("## Configuration");
  lines.push("");
  lines.push(`- llama.cpp: \`${path.relative(repoRoot, args.llamaCli)}\``);
  lines.push(`- target: \`${path.relative(repoRoot, args.model)}\``);
  lines.push(`- draft: \`${path.relative(repoRoot, args.draft)}\``);
  lines.push(`- prompt file: \`${path.relative(repoRoot, args.promptFile)}\``);
  lines.push(`- reps: \`${args.reps}\``);
  lines.push(`- generated token cap: \`${args.tokens}\``);
  lines.push(`- context: \`${args.context}\``);
  lines.push(`- draft n max: \`${args.draftN}\``);
  lines.push("");
  lines.push("Prompt:");
  lines.push("");
  lines.push("```text");
  lines.push(prompt);
  lines.push("```");
  lines.push("");
  lines.push("## Summary");
  lines.push("");
  lines.push("| Variant | Runs | Failures | Median prompt tok/s | Median generation tok/s | Median elapsed ms |");
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: |");
  for (const variant of ["base", "draft"]) {
    const row = summary.byVariant[variant];
    lines.push(`| ${variant} | ${row.runs} | ${row.failures} | ${fmt(row.medianPromptTps)} | ${fmt(row.medianGenerationTps)} | ${fmt(row.medianElapsedMs)} |`);
  }
  lines.push("");
  lines.push(`Generation speedup: \`${fmt(summary.generationSpeedup)}x\``);
  lines.push("");
  lines.push("## Runs");
  lines.push("");
  lines.push("| Variant | Rep | Exit | Prompt tok/s | Generation tok/s | Elapsed ms | Timing line |");
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: | --- |");
  for (const row of results) {
    lines.push(`| ${row.variant} | ${row.rep} | ${row.exitCode ?? ""} | ${fmt(row.promptTps)} | ${fmt(row.generationTps)} | ${fmt(row.elapsedMs)} | \`${row.timingLine ?? ""}\` |`);
  }
  lines.push("");
  fs.writeFileSync(path.join(resultDir, "summary.md"), lines.join("\n"));
}

function fmt(value) {
  return Number.isFinite(value) ? value.toFixed(2) : "";
}

const args = parseArgs(process.argv.slice(2));
mustExist("llama-cli", args.llamaCli);
mustExist("target model", args.model);
mustExist("draft model", args.draft);
mustExist("prompt file", args.promptFile);

const prompt = fs.readFileSync(args.promptFile, "utf8").trim();
const resultDir = path.join(benchDir, "results", args.runName);
fs.mkdirSync(resultDir, { recursive: true });

const results = [];
for (const variant of ["base", "draft"]) {
  for (let rep = 1; rep <= args.reps; rep += 1) {
    console.log(`Running ${variant} rep ${rep}/${args.reps}...`);
    const row = runOne({ variant, rep, args, prompt, resultDir });
    console.log(`${variant} rep ${rep}: exit=${row.exitCode} generation=${row.generationTps ?? "n/a"} tok/s elapsed=${row.elapsedMs} ms`);
    results.push(row);
  }
}

const summary = summarize(results);
const payload = {
  generatedAt: new Date().toISOString(),
  args: {
    ...args,
    llamaCli: path.relative(repoRoot, args.llamaCli),
    model: path.relative(repoRoot, args.model),
    draft: path.relative(repoRoot, args.draft),
    promptFile: path.relative(repoRoot, args.promptFile),
  },
  prompt,
  results,
  summary,
};

fs.writeFileSync(path.join(resultDir, "summary.json"), JSON.stringify(payload, null, 2));
writeMarkdown({ args, prompt, results, summary, resultDir });
console.log(`Wrote ${path.relative(repoRoot, resultDir)}`);
