#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const benchRoot = path.resolve(scriptDir, "..");
const resultsDir = path.join(benchRoot, "results");
const reportsDir = path.join(benchRoot, "reports");
const dataPath = path.join(reportsDir, "local-inference-dashboard-data.json");
const markdownPath = path.join(reportsDir, "local-inference-dashboard.md");
const htmlPath = path.join(reportsDir, "local-inference-dashboard.html");

const projectSummary = {
  updatedThrough: "2026-06-22",
  headline: "Current promoted local coding stack: Qwen3 Coder 30B Q4 is viable at 16k for controlled WSL ROCm work, Pi Docker tool-call validation, Docker-controlled tasks, OpenCode thin-prompt tasks, and Windows LM Studio controlled tasks. Use controlled runners for measurement, Pi for Dockerized executable tool-call validation, and OpenCode as a slower realism benchmark.",
  currentRecommendation: [
    {
      label: "Endpoint",
      value: "WSL ROCm llama.cpp with Qwen3 Coder 30B Q4, CTX_SIZE=16384 when context is useful, PARALLEL=1, LLAMA_JINJA=1 for Pi/tool-call work. Keep 8k as the lower-overhead baseline.",
      links: [
        { label: "Phase 21 16k controlled/Pi", href: "phase-21-16k-controlled-pi-context.html" },
        { label: "Phase 22 16k OpenCode/Windows", href: "phase-22-16k-opencode-windows-models.html" },
        { label: "Phase 20 final recommendation", href: "phase-20-runner-endpoint-final-recommendation.html" },
        { label: "Phase 16 Pi recovery", href: "phase-16-pi-jinja-toolcall-recovery.html" }
      ]
    },
    {
      label: "Runner",
      value: "Use the host/WSL controlled runner as the default benchmark harness; use Docker-controlled for Linux isolation; use Pi when validating Dockerized agentic tool execution; use OpenCode for slower full-agent realism checks.",
      links: [
        { label: "Phase 03 recommendation", href: "phase-03-recommendation.html" },
        { label: "Runner comparison summary", href: "../results/20260622-121739-runner-comparison/runner-comparison-summary.json" }
      ]
    },
    {
      label: "Memory",
      value: "32GB WSL RAM is sufficient for the measured short-context host/WSL and Pi file/edit/browser workflows; 48GB is the practical headroom setting. The 16k runs were not repeated under 32GB yet.",
      links: [
        { label: "Pi memory sweep", href: "phase-18-pi-memory-cap-sweep.html" },
        { label: "32GB controlled sweep", href: "phase-14-memory-cap-32gb.html" }
      ]
    }
  ],
  milestones: [
    {
      area: "Windows LM Studio tuning",
      result: "The Windows path established a fast Qwen3 Coder throughput profile and a separate practical 32k long-context profile. Very large contexts can load, but interactive use breaks down from prompt prefill latency.",
      links: [
        { label: "Vulkan 2.23 experts", href: "../../../reports/2026-06-19_optimization-summary-12-vulkan-223-experts.html" },
        { label: "Long-context final", href: "../../../reports/2026-06-20_optimization-summary-28-long-context-final-report.html" }
      ]
    },
    {
      area: "Long context limit",
      result: "32k is the practical local long-context target. 65k is occasional and slow. 128k+ and 196k+ are not interactive on this hardware; 196k took about 80.5 minutes before generation and decoded at 9.71 tok/s.",
      links: [
        { label: "Long-context ladder", href: "../../../reports/2026-06-20_optimization-summary-28-long-context-final-report.html" }
      ]
    },
    {
      area: "OpenCode behavior",
      result: "Thin source-on-demand prompts were the major TTFT win: Qwen 16k thin/no-padding reached about 12.6s first TTFT on calibration. Autonomous reliability stayed mixed, so OpenCode was not promoted as the main local daily driver.",
      links: [
        { label: "OpenCode final", href: "../../../reports/2026-06-20_optimization-summary-29-opencode-agent-benchmark-final.html" },
        { label: "OpenCode TTFT profile", href: "../../../reports/2026-06-20_optimization-summary-30-opencode-ttft-practical-profile.html" },
        { label: "Thin prompt sweep", href: "../../../reports/2026-06-20_optimization-summary-31-opencode-thin-prompt-ttft-sweep.html" }
      ]
    },
    {
      area: "WSL2 ROCm runtime",
      result: "Ubuntu 24.04 WSL2 plus AMD ROCDXG/ROCm and AMD's validated llama.cpp binary became the winning Linux path. ROCm works; WSL Vulkan currently reports llvmpipe CPU rather than the AMD GPU.",
      links: [
        { label: "WSL ROCm runtime", href: "phase-01-wsl-rocm-runtime.html" },
        { label: "WSL runbook", href: "../setup-runbook.md" },
        { label: "WSL setup report", href: "../../../reports/2026-06-21_optimization-summary-33-wsl-opencode-runner-and-setup-runbook.html" }
      ]
    },
    {
      area: "Controlled coding benchmarks",
      result: "Qwen3 Coder 30B Q4 passed controlled JS edit and protected browser-style frontend tasks with browser verification. Docker-controlled also passed, making it the preferred Linux-container measurement lane.",
      links: [
        { label: "Phase 03 recommendation", href: "phase-03-recommendation.html" },
        { label: "Docker-controlled agent", href: "phase-13-docker-controlled-agent.html" }
      ]
    },
    {
      area: "Pi tool calling",
      result: "The Pi failure was endpoint format, not basic Docker reachability. llama.cpp needed --jinja for structured OpenAI tool calls, and Pi needed the local Qwen tool-call reminder. With both, Pi executed real toolCall/toolResult events.",
      links: [
        { label: "Tool-call compatibility", href: "phase-15-pi-tool-call-compatibility.html" },
        { label: "Pi Jinja recovery", href: "phase-16-pi-jinja-toolcall-recovery.html" }
      ]
    },
    {
      area: "Pi reliability",
      result: "Pi passed a 10-run file/edit/browser soak, a five-task challenge suite, DEFAULT/48GB/32GB memory caps, runner comparison, and Q4/Q2 endpoint comparison. It is viable for small local tasks, but operationally heavier than controlled runners.",
      links: [
        { label: "Challenge suite and dashboard", href: "phase-17-pi-soak-challenge-dashboard.html" },
        { label: "10-run soak", href: "phase-19-pi-10-run-soak.html" },
        { label: "Final recommendation", href: "phase-20-runner-endpoint-final-recommendation.html" }
      ]
    },
    {
      area: "16k context reality check",
      result: "16k is realistic for this project. Qwen3 Coder 30B Q4 passed controlled WSL 8k vs 16k comparison, Pi Jinja file/edit/browser, Pi five-task challenge suite, Docker-controlled, OpenCode thin-prompt js-window and browser-style, and Windows LM Studio controlled tasks. Windows LM Studio was faster on controlled first-content timings; OpenCode passed but remained slow and tool-heavy.",
      links: [
        { label: "Phase 21 16k controlled/Pi", href: "phase-21-16k-controlled-pi-context.html" },
        { label: "Phase 22 16k OpenCode/Windows", href: "phase-22-16k-opencode-windows-models.html" },
        { label: "16k WSL controlled summary", href: "../results/20260622-133115-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json" },
        { label: "16k OpenCode summary", href: "../results/20260622-140434-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json" },
        { label: "Windows LM Studio 16k summary", href: "../results/20260622-142238-windows-lmstudio-16k-controlled/windows-lmstudio-16k-controlled-summary.json" }
      ]
    }
  ],
  canonicalArtifacts: [
    { label: "Promoted Pi workflow", href: "../results/20260622-102758-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json" },
    { label: "Pi challenge suite", href: "../results/20260622-110232-pi-challenge-suite/pi-challenge-suite-summary.json" },
    { label: "Pi memory sweep", href: "../results/20260622-111737-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json" },
    { label: "Pi 10-run soak", href: "../results/20260622-113256-pi-reliability-soak/pi-reliability-soak-summary.json" },
    { label: "Runner comparison", href: "../results/20260622-121739-runner-comparison/runner-comparison-summary.json" },
    { label: "Endpoint comparison", href: "../results/20260622-120346-pi-endpoint-comparison/pi-endpoint-comparison-summary.json" },
    { label: "16k controlled WSL comparison", href: "../results/20260622-133115-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json" },
    { label: "16k Pi challenge suite", href: "../results/20260622-134255-pi-challenge-suite/pi-challenge-suite-summary.json" },
    { label: "16k OpenCode workflow", href: "../results/20260622-140434-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json" },
    { label: "16k Windows LM Studio controlled", href: "../results/20260622-142238-windows-lmstudio-16k-controlled/windows-lmstudio-16k-controlled-summary.json" }
  ],
  openLimits: [
    "Large frontend applications and larger multi-file product work remain untested under Pi and OpenCode.",
    "The 16k lanes have not been repeated as a 10-run reliability soak.",
    "The 16k lanes have not been repeated under the 32GB WSL memory cap.",
    "LM Studio and Ollama were not re-promoted for executable tool-call work because the WSL ROCm llama.cpp Jinja endpoint already passed that gate.",
    "OpenCode passed two 16k tasks, but browser-style took over six minutes and 20 steps; it is not the fast default harness.",
    "Qwen2.5 Coder 1.5B Q4/Q8 are fast but failed verifier-backed controlled tasks."
  ]
};

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, out);
    } else {
      out.push(full);
    }
  }
  return out;
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    return { parseError: String(error) };
  }
}

function rel(file, from = reportsDir) {
  return path.relative(from, file).replace(/\\/g, "/");
}

function escapeHtml(text) {
  return String(text ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function detectKind(file, json) {
  const name = path.basename(file);
  if (name.includes("pi-challenge-suite")) return "pi-challenge-suite";
  if (name.includes("runner-comparison")) return "runner-comparison";
  if (name.includes("pi-endpoint-comparison")) return "endpoint-comparison";
  if (name.includes("pi-reliability-soak")) return "pi-soak";
  if (name.includes("pi-jinja-q4-toolcall-workflow")) return "pi-workflow";
  if (name.includes("docker-controlled")) return "docker-controlled";
  if (name.includes("recommended-q4")) return "recommended-q4";
  if (name.includes("memory-cap")) return "memory-cap";
  if (name.includes("model-matrix")) return "model-matrix";
  if (json.validation) return "validation";
  return "summary";
}

function detectPassed(json) {
  if (typeof json.passed === "boolean") return json.passed;
  if (typeof json.pass === "boolean") return json.pass;
  if (typeof json.ok === "boolean") return json.ok;
  if (json.comparisonCompleted === true && Array.isArray(json.rows)) {
    return json.rows.length > 0 && json.rows.every((row) => row.passed === true);
  }
  return null;
}

function summarizeTasks(json) {
  if (Array.isArray(json.taskResults)) {
    return json.taskResults.map((task) => `${task.task ?? task.name}:${task.passed === true ? "pass" : task.passed === false ? "fail" : "unknown"}`);
  }
  if (Array.isArray(json.tasks)) {
    return json.tasks.map((task) => typeof task === "string" ? task : task.task ?? task.name ?? "task");
  }
  if (Array.isArray(json.rows)) {
    return json.rows.map((row) => `${row.variant ?? row.memoryCap ?? "row"}:${row.passed === true ? "pass" : row.passed === false ? "fail" : "unknown"}`);
  }
  if (Array.isArray(json.runners)) {
    return json.runners.map((runner) => `${runner.runner ?? runner.name ?? "runner"}:${runner.passed === true ? "pass" : runner.passed === false ? "fail" : "unknown"}`);
  }
  return [];
}

function resultRow(file) {
  const json = readJson(file);
  const dir = path.dirname(file);
  const stat = fs.statSync(file);
  const kind = detectKind(file, json);
  const passed = detectPassed(json);
  return {
    kind,
    name: path.basename(dir),
    summary: file,
    summaryRel: rel(file),
    resultDir: dir,
    resultRel: rel(dir),
    createdAt: json.createdAt ?? null,
    completedAt: json.completedAt ?? null,
    model: json.modelAlias ?? json.model ?? json.piModelArg ?? null,
    passed,
    sizeBytes: stat.size,
    tasks: summarizeTasks(json),
    parseError: json.parseError ?? null
  };
}

function reportRows() {
  if (!fs.existsSync(reportsDir)) return [];
  return fs.readdirSync(reportsDir)
    .filter((name) => name.endsWith(".md") || name.endsWith(".html"))
    .sort()
    .map((name) => ({
      name,
      path: path.join(reportsDir, name),
      rel: name
    }));
}

function statusText(value) {
  if (value === true) return "pass";
  if (value === false) return "fail";
  return "unknown";
}

function markdownLinks(links) {
  return links.map((link) => `[${link.label}](${link.href})`).join(", ");
}

function htmlLinks(links) {
  return links.map((link) => `<a href="${escapeHtml(link.href)}">${escapeHtml(link.label)}</a>`).join(", ");
}

function writeMarkdown(rows, reports) {
  const lines = [
    "# Local Inference Dashboard",
    "",
    `Generated: ${new Date().toISOString()}`,
    "",
    "## Abridged Project State",
    "",
    projectSummary.headline,
    "",
    `Updated through: ${projectSummary.updatedThrough}`,
    "",
    "## Current Recommendation",
    "",
    "| Layer | Recommendation | Links |",
    "| --- | --- | --- |"
  ];
  for (const row of projectSummary.currentRecommendation) {
    lines.push(`| ${row.label} | ${row.value} | ${markdownLinks(row.links)} |`);
  }
  lines.push(
    "",
    "## Experiment Milestones",
    "",
    "| Area | What Was Learned | Links |",
    "| --- | --- | --- |"
  );
  for (const milestone of projectSummary.milestones) {
    lines.push(`| ${milestone.area} | ${milestone.result} | ${markdownLinks(milestone.links)} |`);
  }
  lines.push("", "## Canonical Artifacts", "");
  for (const artifact of projectSummary.canonicalArtifacts) {
    lines.push(`- [${artifact.label}](${artifact.href})`);
  }
  lines.push("", "## Remaining Limits", "");
  for (const item of projectSummary.openLimits) {
    lines.push(`- ${item}`);
  }
  lines.push(
    "",
    "## Raw Result Index",
    "",
    "| Kind | Result | Status | Model | Tasks | Summary |",
    "| --- | --- | --- | --- | --- | --- |"
  );
  for (const row of rows) {
    lines.push(`| ${row.kind} | ${row.name} | ${statusText(row.passed)} | ${row.model ?? ""} | ${row.tasks.join(", ")} | ${row.summaryRel} |`);
  }
  lines.push("", "## Rendered Benchmark Reports", "");
  for (const report of reports.filter((item) => item.name.endsWith(".html"))) {
    lines.push(`- ${report.rel}`);
  }
  fs.writeFileSync(markdownPath, `${lines.join("\n")}\n`, "utf8");
}

function writeHtml(rows, reports) {
  const cards = rows.map((row) => {
    const status = statusText(row.passed);
    return `<tr class="${status}">
      <td>${escapeHtml(row.kind)}</td>
      <td><a href="${escapeHtml(row.resultRel)}">${escapeHtml(row.name)}</a></td>
      <td>${escapeHtml(status)}</td>
      <td>${escapeHtml(row.model ?? "")}</td>
      <td>${escapeHtml(row.tasks.join(", "))}</td>
      <td><a href="${escapeHtml(row.summaryRel)}">summary</a></td>
    </tr>`;
  }).join("\n");

  const reportLinks = reports
    .filter((report) => report.name.endsWith(".html"))
    .map((report) => `<li><a href="${escapeHtml(report.rel)}">${escapeHtml(report.name)}</a></li>`)
    .join("\n");

  const recommendationRows = projectSummary.currentRecommendation.map((row) => `<tr>
      <td>${escapeHtml(row.label)}</td>
      <td>${escapeHtml(row.value)}</td>
      <td>${htmlLinks(row.links)}</td>
    </tr>`).join("\n");

  const milestoneRows = projectSummary.milestones.map((milestone) => `<tr>
      <td>${escapeHtml(milestone.area)}</td>
      <td>${escapeHtml(milestone.result)}</td>
      <td>${htmlLinks(milestone.links)}</td>
    </tr>`).join("\n");

  const artifactLinks = projectSummary.canonicalArtifacts
    .map((artifact) => `<li><a href="${escapeHtml(artifact.href)}">${escapeHtml(artifact.label)}</a></li>`)
    .join("\n");

  const limitItems = projectSummary.openLimits
    .map((item) => `<li>${escapeHtml(item)}</li>`)
    .join("\n");

  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Local Inference Dashboard</title>
  <style>
    :root { color-scheme: light dark; }
    body { font-family: "Segoe UI", system-ui, sans-serif; margin: 0; line-height: 1.45; }
    main { max-width: 1180px; margin: 0 auto; padding: 28px 18px 52px; }
    h1, h2 { line-height: 1.2; }
    .lede { font-size: 18px; max-width: 980px; }
    .summary-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(260px, 0.42fr); gap: 24px; align-items: start; }
    .sidebox { border-left: 4px solid #8885; padding-left: 16px; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { border: 1px solid #8885; padding: 7px 8px; text-align: left; vertical-align: top; }
    th { background: #8881; position: sticky; top: 0; }
    tr.pass td:nth-child(3) { color: #157f3b; font-weight: 700; }
    tr.fail td:nth-child(3) { color: #b42318; font-weight: 700; }
    tr.unknown td:nth-child(3) { color: #8a6100; font-weight: 700; }
    a { color: LinkText; }
    .meta { color: #666; }
    @media (max-width: 760px) {
      .summary-grid { grid-template-columns: 1fr; }
      table { font-size: 12px; }
      th, td { padding: 5px; }
    }
  </style>
</head>
<body>
<main>
  <h1>Local Inference Dashboard</h1>
  <p class="meta">Generated: ${escapeHtml(new Date().toISOString())}</p>
  <h2>Abridged Project State</h2>
  <p class="lede">${escapeHtml(projectSummary.headline)}</p>
  <p class="meta">Updated through: ${escapeHtml(projectSummary.updatedThrough)}</p>

  <h2>Current Recommendation</h2>
  <table>
    <thead><tr><th>Layer</th><th>Recommendation</th><th>Links</th></tr></thead>
    <tbody>${recommendationRows}</tbody>
  </table>

  <h2>Experiment Milestones</h2>
  <table>
    <thead><tr><th>Area</th><th>What Was Learned</th><th>Links</th></tr></thead>
    <tbody>${milestoneRows}</tbody>
  </table>

  <div class="summary-grid">
    <section>
      <h2>Canonical Artifacts</h2>
      <ul>${artifactLinks}</ul>
    </section>
    <section class="sidebox">
      <h2>Remaining Limits</h2>
      <ul>${limitItems}</ul>
    </section>
  </div>

  <h2>Raw Result Index</h2>
  <table>
    <thead><tr><th>Kind</th><th>Result</th><th>Status</th><th>Model</th><th>Tasks</th><th>Summary</th></tr></thead>
    <tbody>${cards}</tbody>
  </table>
  <h2>Rendered Benchmark Reports</h2>
  <ul>${reportLinks}</ul>
</main>
</body>
</html>
`;
  fs.writeFileSync(htmlPath, html, "utf8");
}

function main() {
  fs.mkdirSync(reportsDir, { recursive: true });
  const summaries = walk(resultsDir)
    .filter((file) => file.endsWith(".json") && path.basename(file).includes("summary"))
    .map(resultRow)
    .sort((a, b) => String(b.createdAt ?? b.name).localeCompare(String(a.createdAt ?? a.name)));
  const reports = reportRows();
  const data = {
    generatedAt: new Date().toISOString(),
    projectSummary,
    resultsDir,
    reportsDir,
    summaries,
    reports
  };
  fs.writeFileSync(dataPath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  writeMarkdown(summaries, reports);
  writeHtml(summaries, reports);
  console.log(JSON.stringify({
    summaries: summaries.length,
    reports: reports.length,
    data: rel(dataPath),
    markdown: rel(markdownPath),
    html: rel(htmlPath)
  }, null, 2));
}

main();
