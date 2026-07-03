#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const benchRoot = path.resolve(scriptDir, "..");
const resultsDir = path.join(benchRoot, "results");
const reportsDir = path.join(benchRoot, "reports");

function parseOptions(argv) {
  const out = { inputs: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--input") {
      out.inputs.push(argv[++i]);
    } else if (arg === "--inputs") {
      out.inputs.push(...String(argv[++i] ?? "").split(",").map((item) => item.trim()).filter(Boolean));
    } else if (arg === "--out-json") {
      out.outJson = argv[++i];
    } else if (arg === "--out-md") {
      out.outMd = argv[++i];
    } else if (arg === "--help" || arg === "-h") {
      out.help = true;
    } else {
      out.inputs.push(arg);
    }
  }
  return out;
}

function usage() {
  return `Usage:
  node scripts/summarize-real-usage-results.mjs --inputs path/to/matrix-summary.json[,more.json] [--out-json PATH] [--out-md PATH]

If no inputs are provided, the script scans benchmark results for *matrix-summary.json files.`;
}

function findMatrixSummaries(root) {
  const out = [];
  if (!fs.existsSync(root)) return out;
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) {
      out.push(...findMatrixSummaries(full));
    } else if (entry.name.endsWith("matrix-summary.json")) {
      out.push(full);
    }
  }
  return out.sort();
}

function readJsonMaybe(file) {
  if (!file || !fs.existsSync(file)) return null;
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

function asArray(value) {
  if (value === undefined || value === null) return [];
  return Array.isArray(value) ? value : [value];
}

function relFromReports(file) {
  if (!file) return "";
  return path.relative(reportsDir, path.resolve(file)).replace(/\\/g, "/");
}

function relFromBench(file) {
  if (!file) return "";
  return path.relative(benchRoot, path.resolve(file)).replace(/\\/g, "/");
}

function runnerName(matrixRunner) {
  return String(matrixRunner ?? "")
    .replace(/^lmstudio-/, "")
    .replace(/-matrix$/, "");
}

function runnerLabel(matrix) {
  const base = runnerName(matrix?.runner);
  return matrix?.endpointName ? `${base}:${matrix.endpointName}` : base;
}

function bestAttemptForMetrics(summary) {
  const attempts = asArray(summary?.attempts);
  if (attempts.length === 0) return null;
  return attempts.find((attempt) => attempt.passed === true) ?? attempts[attempts.length - 1];
}

function metricsFromTaskRow(taskRow) {
  if (taskRow?.metrics) return taskRow.metrics;
  const nestedSummary = readJsonMaybe(taskRow?.summary) ?? readJsonMaybe(taskRow?.stdoutSummary);
  if (nestedSummary?.metrics) return nestedSummary.metrics;
  const attempt = bestAttemptForMetrics(nestedSummary);
  return attempt?.metrics ?? null;
}

function failureClass({ passed, timedOut, verification, modifiedFiles }) {
  if (passed === true) return "pass";
  if ((verification?.allowlistViolations ?? []).length > 0) return "allowlist";
  if ((verification?.protectedViolations ?? []).length > 0) return "protected-text";
  if (verification?.canary?.unchanged === false) return "canary";
  if (timedOut) return "timeout";
  if (verification?.verification?.exitCode !== undefined && verification.verification.exitCode !== 0) return "verifier";
  if (Array.isArray(modifiedFiles) && modifiedFiles.length === 0) return "no-edit";
  return "unknown";
}

function flattenMatrix(file) {
  const matrix = readJsonMaybe(file);
  if (!matrix) return [];
  const rows = [];
  for (const modelRow of asArray(matrix.rows)) {
    for (const taskRow of asArray(modelRow.taskRows)) {
      const verification = readJsonMaybe(taskRow.verification);
      const modifiedFiles = verification?.modifiedFiles ?? [];
      const timedOut = Boolean(taskRow.runnerTimedOut ?? taskRow.run?.timedOut ?? false);
      const passed = Boolean(taskRow.passed === true || verification?.passed === true);
      const metrics = metricsFromTaskRow(taskRow);
      rows.push({
        matrixRunId: matrix.runId ?? path.basename(path.dirname(file)),
        matrixSummary: relFromBench(file),
        runner: runnerLabel(matrix),
        model: modelRow.model ?? matrix.model ?? "",
        task: taskRow.task ?? "",
        passed,
        failureClass: failureClass({ passed, timedOut, verification, modifiedFiles }),
        runnerCompleted: taskRow.runnerCompleted ?? (taskRow.run?.exitCode === 0),
        runnerTimedOut: timedOut,
        verifierPassed: taskRow.verifierPassed ?? verification?.passed ?? null,
        elapsedMs: taskRow.run?.elapsedMs ?? null,
        toolCallCount: taskRow.toolCallCount ?? null,
        failedToolCalls: taskRow.failedToolCalls ?? null,
        ttftMs: metrics?.ttftMs ?? null,
        firstByteMs: metrics?.firstByteMs ?? null,
        outputTokensPerSecond: metrics?.outputTokensPerSecond ?? null,
        wallOutputTokensPerSecond: metrics?.wallOutputTokensPerSecond ?? null,
        inputTokens: metrics?.inputTokens ?? null,
        outputTokens: metrics?.outputTokens ?? null,
        totalTokens: metrics?.totalTokens ?? null,
        reasoningTokens: metrics?.reasoningTokens ?? null,
        ttftSource: metrics?.ttftSource ?? null,
        modifiedFiles,
        allowlistViolations: verification?.allowlistViolations ?? [],
        protectedViolations: verification?.protectedViolations ?? [],
        canaryUnchanged: verification?.canary?.unchanged ?? null,
        verificationExitCode: verification?.verification?.exitCode ?? null,
        summaryPath: relFromBench(modelRow.summaryPath ?? ""),
        verificationPath: relFromBench(taskRow.verification ?? "")
      });
    }
  }
  return rows;
}

function summarize(rows, inputs) {
  const byRunnerModel = new Map();
  const addMetric = (target, name, value) => {
    if (value === null || value === undefined || value === "") return;
    const number = Number(value);
    if (!Number.isFinite(number)) return;
    target[`${name}Sum`] = (target[`${name}Sum`] ?? 0) + number;
    target[`${name}Count`] = (target[`${name}Count`] ?? 0) + 1;
  };
  for (const row of rows) {
    const key = `${row.runner}\t${row.model}`;
    const current = byRunnerModel.get(key) ?? {
      runner: row.runner,
      model: row.model,
      tasks: 0,
      passes: 0,
      timeouts: 0,
      allowlistViolations: 0,
      failedToolCalls: 0,
      toolCalls: 0
    };
    current.tasks += 1;
    if (row.passed) current.passes += 1;
    if (row.runnerTimedOut) current.timeouts += 1;
    if (row.allowlistViolations.length > 0) current.allowlistViolations += 1;
    current.failedToolCalls += Number(row.failedToolCalls ?? 0);
    current.toolCalls += Number(row.toolCallCount ?? 0);
    addMetric(current, "ttftMs", row.ttftMs);
    addMetric(current, "outputTokensPerSecond", row.outputTokensPerSecond);
    addMetric(current, "wallOutputTokensPerSecond", row.wallOutputTokensPerSecond);
    addMetric(current, "outputTokens", row.outputTokens);
    byRunnerModel.set(key, current);
  }
  const overviewRows = [...byRunnerModel.values()].map((row) => ({
    ...row,
    avgTtftMs: row.ttftMsCount ? Number((row.ttftMsSum / row.ttftMsCount).toFixed(1)) : null,
    avgOutputTokensPerSecond: row.outputTokensPerSecondCount ? Number((row.outputTokensPerSecondSum / row.outputTokensPerSecondCount).toFixed(2)) : null,
    avgWallOutputTokensPerSecond: row.wallOutputTokensPerSecondCount ? Number((row.wallOutputTokensPerSecondSum / row.wallOutputTokensPerSecondCount).toFixed(2)) : null,
    avgOutputTokens: row.outputTokensCount ? Number((row.outputTokensSum / row.outputTokensCount).toFixed(1)) : null
  }));
  return {
    createdAt: new Date().toISOString(),
    inputs: inputs.map(relFromBench),
    rowCount: rows.length,
    byRunnerModel: overviewRows.sort((a, b) =>
      a.runner.localeCompare(b.runner) || a.model.localeCompare(b.model)
    ),
    rows
  };
}

function mdTable(headers, rows) {
  const clean = (value) => String(value ?? "").replace(/\r?\n/g, " ").replace(/\|/g, "\\|");
  return [
    `| ${headers.join(" | ")} |`,
    `| ${headers.map(() => "---").join(" | ")} |`,
    ...rows.map((row) => `| ${row.map(clean).join(" | ")} |`)
  ].join("\n");
}

function renderMarkdown(summary) {
  const overview = mdTable(
    ["Runner", "Model", "Passes", "Tasks", "Timeouts", "Avg TTFT ms", "Avg TPS", "Avg Wall TPS", "Tools", "Failed Tools"],
    summary.byRunnerModel.map((row) => [
      row.runner,
      `\`${row.model}\``,
      row.passes,
      row.tasks,
      row.timeouts,
      row.avgTtftMs ?? "",
      row.avgOutputTokensPerSecond ?? "",
      row.avgWallOutputTokensPerSecond ?? "",
      row.toolCalls || "",
      row.failedToolCalls || ""
    ])
  );
  const details = mdTable(
    ["Runner", "Model", "Task", "Pass", "Class", "Timeout", "TTFT ms", "TPS", "Tokens Out", "Tools", "Failed", "Modified", "Verification"],
    summary.rows.map((row) => [
      row.runner,
      `\`${row.model}\``,
      `\`${row.task}\``,
      row.passed ? "yes" : "no",
      row.failureClass,
      row.runnerTimedOut ? "yes" : "no",
      row.ttftMs ?? "",
      row.outputTokensPerSecond ?? row.wallOutputTokensPerSecond ?? "",
      row.outputTokens ?? "",
      row.toolCallCount ?? "",
      row.failedToolCalls ?? "",
      row.modifiedFiles.join(", "),
      row.verificationPath ? `[json](${relFromReports(path.join(benchRoot, row.verificationPath))})` : ""
    ])
  );
  return `# Real-Usage Result Rollup

Generated: ${summary.createdAt}

Inputs:
${summary.inputs.map((input) => `- [${input}](${relFromReports(path.join(benchRoot, input))})`).join("\n")}

## Overview

${overview}

## Task Rows

${details}
`;
}

const options = parseOptions(process.argv.slice(2));
if (options.help) {
  process.stdout.write(`${usage()}\n`);
  process.exit(0);
}

const inputs = (options.inputs.length ? options.inputs : findMatrixSummaries(resultsDir))
  .map((input) => path.resolve(input));
const rows = inputs.flatMap(flattenMatrix);
const summary = summarize(rows, inputs);

if (options.outJson) {
  const target = path.resolve(options.outJson);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
}
if (options.outMd) {
  const target = path.resolve(options.outMd);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, renderMarkdown(summary), "utf8");
}

process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
