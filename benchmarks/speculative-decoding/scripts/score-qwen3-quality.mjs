#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const resultDirs = process.argv.slice(2);
if (resultDirs.length === 0) {
  console.error("Usage: node score-qwen3-quality.mjs <result-dir>...");
  process.exit(1);
}

function median(values) {
  const sorted = values.filter((value) => Number.isFinite(value)).sort((a, b) => a - b);
  if (sorted.length === 0) return null;
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

function readText(file) {
  const buffer = readFileSync(file);
  if (buffer.length >= 2 && buffer[0] === 0xff && buffer[1] === 0xfe) {
    return buffer.toString("utf16le").replace(/^\uFEFF/, "");
  }
  const sample = buffer.subarray(0, Math.min(buffer.length, 400));
  let oddNulls = 0;
  for (let index = 1; index < sample.length; index += 2) {
    if (sample[index] === 0) oddNulls += 1;
  }
  if (oddNulls > sample.length / 6) {
    return buffer.toString("utf16le").replace(/^\uFEFF/, "");
  }
  return buffer.toString("utf8").replace(/^\uFEFF/, "");
}

function normalizeText(text) {
  return text.replace(/\r\n/g, "\n").replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim();
}

function hashText(text) {
  return createHash("sha256").update(text).digest("hex").slice(0, 12);
}

function extractGenerated(stdout, prompt) {
  const lines = stdout.replace(/\r\n/g, "\n").split("\n");
  const promptLines = prompt.replace(/\r\n/g, "\n").split("\n");
  const promptStart = lines.findIndex((line) => line.startsWith("> "));
  if (promptStart < 0) return "";

  let start = promptStart + promptLines.length;
  while (start < lines.length && lines[start].trim() === "") start += 1;

  let end = lines.findIndex((line, index) => index >= start && /^\[ Prompt:\s*/.test(line));
  if (end < 0) end = lines.length;
  while (end > start && lines[end - 1].trim() === "") end -= 1;

  return lines.slice(start, end).join("\n").trim();
}

function hasAny(text, values) {
  const lower = text.toLowerCase();
  return values.some((value) => lower.includes(value.toLowerCase()));
}

function scoreCodingPattern(text) {
  const checks = [
    ["exports functions", /\bexport\b/.test(text)],
    ["validateEmail", /validateEmail/i.test(text)],
    ["validateAge", /validateAge/i.test(text)],
    ["validateRole", /validateRole/i.test(text)],
    ["validateStatus", /validateStatus/i.test(text)],
    ["validateDisplayName", /validateDisplayName/i.test(text)],
    ["email rule", /@|\\s@\]|\^\[/.test(text) || /email/i.test(text)],
    ["age bounds", /age[\s\S]{0,120}(>=|>|number|integer)/i.test(text)],
    ["role allowed values", hasAny(text, ["admin", "user", "guest", "includes"]),
    ],
    ["boolean-return style", /=>|return/.test(text) && /true|false|test|includes/.test(text)],
  ];
  return { score: checks.filter(([, passed]) => passed).length, max: checks.length, checks };
}

function scoreRepetitiveValidator(text) {
  const fields = [
    "postalCode",
    "timezone",
    "language",
    "department",
    "title",
    "managerId",
    "employeeId",
    "costCenter",
    "region",
    "notes",
    "createdBy",
    "updatedBy",
    "externalId",
    "avatarUrl",
    "website",
    "github",
    "linkedin",
    "slack",
    "teams",
    "pagerDuty",
  ];
  const lower = text.toLowerCase();
  const found = fields.filter((field) => lower.includes(field.toLowerCase()));
  const syntaxChecks = [
    ["arrow functions", /=>/.test(text)],
    ["validator object continuation", /typeof|Number\.|includes|length/.test(text)],
    ["minimal prose", !/(here is|below is|sure|explanation)/i.test(text)],
  ];
  const fieldScore = (found.length / fields.length) * 7;
  const syntaxScore = syntaxChecks.filter(([, passed]) => passed).length;
  return {
    score: fieldScore + syntaxScore,
    max: 10,
    checks: [
      [`fields present ${found.length}/${fields.length}`, found.length],
      ...syntaxChecks,
    ],
  };
}

function scoreRefactorExplanation(text) {
  const checks = [
    ["has refactor plan", /plan|refactor|improve|steps/i.test(text)],
    ["has code block", /```/.test(text)],
    ["keeps fetchUser", /fetchUser/.test(text)],
    ["safe URL/id handling", /encodeURIComponent|new URL|URLSearchParams/i.test(text)],
    ["checks response.ok", /response\.ok/.test(text)],
    ["descriptive HTTP error", /status|statusText|HTTP|failed to fetch/i.test(text)],
    ["typed user shape", /\binterface\b|\btype\b|User\b/.test(text)],
    ["handles parsed JSON", /\.json\(\)|unknown|data\./.test(text)],
    ["normalizes active boolean", /active[\s\S]{0,80}=== true|Boolean\(/i.test(text)],
    ["self-contained", !/import\s+/.test(text)],
  ];
  return { score: checks.filter(([, passed]) => passed).length, max: checks.length, checks };
}

function scoreOutput(promptFile, text) {
  const name = path.basename(promptFile);
  if (name.includes("repetitive-validator")) return scoreRepetitiveValidator(text);
  if (name.includes("refactor-explanation")) return scoreRefactorExplanation(text);
  return scoreCodingPattern(text);
}

const allRows = [];
const runSummaries = [];

for (const dir of resultDirs) {
  const summaryPath = path.join(dir, "summary.json");
  const summary = JSON.parse(readText(summaryPath));
  const promptFile = summary.config.promptFile;
  const promptName = path.basename(promptFile);

  const rows = summary.rows.map((row) => {
    const stdout = readText(path.join(dir, row.stdout));
    const generated = extractGenerated(stdout, summary.prompt);
    const normalized = normalizeText(generated);
    const quality = scoreOutput(promptFile, generated);
    return {
      runName: summary.runName,
      prompt: promptName,
      variant: row.variant,
      rep: row.rep,
      generationTps: row.generationTps,
      elapsedMs: row.elapsedMs,
      outputChars: generated.length,
      outputHash: hashText(normalized),
      qualityScore: quality.score,
      qualityMax: quality.max,
      qualityPct: quality.max > 0 ? (quality.score / quality.max) * 100 : null,
      generated,
      normalized,
    };
  });

  for (const row of rows) allRows.push(row);

  const baseRows = rows.filter((row) => row.variant === "base");
  const variantRows = rows.filter((row) => row.variant !== "base");
  const comparisons = variantRows.map((row) => {
    const base = baseRows.find((candidate) => candidate.rep === row.rep) ?? baseRows[0];
    return {
      variant: row.variant,
      rep: row.rep,
      exactMatchBase: base ? row.generated === base.generated : false,
      normalizedMatchBase: base ? row.normalized === base.normalized : false,
      baseHash: base?.outputHash ?? null,
      outputHash: row.outputHash,
    };
  });

  const byVariant = [...new Set(rows.map((row) => row.variant))].map((variant) => {
    const variantRowsForSummary = rows.filter((row) => row.variant === variant);
    return {
      variant,
      medianQualityPct: median(variantRowsForSummary.map((row) => row.qualityPct)),
      medianGenerationTps: median(variantRowsForSummary.map((row) => row.generationTps)),
      medianOutputChars: median(variantRowsForSummary.map((row) => row.outputChars)),
    };
  });

  runSummaries.push({
    runName: summary.runName,
    prompt: promptName,
    reasoningOff: summary.config.reasoningOff,
    tokens: summary.config.tokens,
    byVariant,
    comparisons,
  });
}

const aggregateByVariant = [...new Set(allRows.map((row) => row.variant))].map((variant) => {
  const rows = allRows.filter((row) => row.variant === variant);
  return {
    variant,
    medianQualityPct: median(rows.map((row) => row.qualityPct)),
    medianGenerationTps: median(rows.map((row) => row.generationTps)),
    medianOutputChars: median(rows.map((row) => row.outputChars)),
  };
});

const exactComparisons = runSummaries.flatMap((summary) => summary.comparisons);
const payload = {
  generatedAt: new Date().toISOString(),
  resultDirs,
  aggregateByVariant,
  exactMatchComparisons: {
    comparisons: exactComparisons.length,
    exactMatches: exactComparisons.filter((comparison) => comparison.exactMatchBase).length,
    normalizedMatches: exactComparisons.filter((comparison) => comparison.normalizedMatchBase).length,
  },
  runs: runSummaries,
};

const md = [];
md.push("# Qwen3 Quality Score Summary");
md.push("");
md.push("Task-specific automated rubric. Scores are heuristic checks for requested fields, code shape, and refactor features; they are not a human preference evaluation.");
md.push("");
md.push("## Aggregate");
md.push("");
md.push("| Variant | Median quality | Median generation tok/s | Median output chars |");
md.push("| --- | ---: | ---: | ---: |");
for (const row of aggregateByVariant) {
  md.push(`| ${row.variant} | ${row.medianQualityPct?.toFixed(1) ?? ""}% | ${row.medianGenerationTps?.toFixed(2) ?? ""} | ${row.medianOutputChars?.toFixed(0) ?? ""} |`);
}
md.push("");
md.push(`Exact output matches vs base: ${payload.exactMatchComparisons.exactMatches}/${payload.exactMatchComparisons.comparisons}.`);
md.push(`Normalized output matches vs base: ${payload.exactMatchComparisons.normalizedMatches}/${payload.exactMatchComparisons.comparisons}.`);
md.push("");
md.push("## Runs");
md.push("");
md.push("| Prompt | Variant | Median quality | Median generation tok/s | Median output chars |");
md.push("| --- | --- | ---: | ---: | ---: |");
for (const summary of runSummaries) {
  for (const row of summary.byVariant) {
    md.push(`| ${summary.prompt} | ${row.variant} | ${row.medianQualityPct?.toFixed(1) ?? ""}% | ${row.medianGenerationTps?.toFixed(2) ?? ""} | ${row.medianOutputChars?.toFixed(0) ?? ""} |`);
  }
}
md.push("");
md.push("## Exactness");
md.push("");
md.push("| Prompt | Variant | Rep | Exact match base | Normalized match base | Base hash | Variant hash |");
md.push("| --- | --- | ---: | ---: | ---: | --- | --- |");
for (const summary of runSummaries) {
  for (const comparison of summary.comparisons) {
    md.push(`| ${summary.prompt} | ${comparison.variant} | ${comparison.rep} | ${comparison.exactMatchBase} | ${comparison.normalizedMatchBase} | ${comparison.baseHash} | ${comparison.outputHash} |`);
  }
}
md.push("");

const outDir = resultDirs[0];
writeFileSync(path.join(outDir, "quality-summary.json"), `${JSON.stringify(payload, null, 2)}\n`);
writeFileSync(path.join(outDir, "quality-summary.md"), md.join("\n"));

console.log(md.join("\n"));
