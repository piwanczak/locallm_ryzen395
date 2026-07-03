#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const runDir = args[0] ? path.resolve(args[0]) : null;
const outIndex = args.indexOf("--out");
const outPath = outIndex >= 0 ? path.resolve(args[outIndex + 1]) : null;

if (!runDir || !outPath) {
  console.error("Usage: node scripts/summarize-kebab-results.mjs <results/run-id> --out <reports/file.md>");
  process.exit(1);
}

const summaryPath = path.join(runDir, "summary.json");
const summary = JSON.parse(fs.readFileSync(summaryPath, "utf8"));

function rel(target) {
  return path.relative(path.dirname(outPath), target).replace(/\\/g, "/");
}

function fmtSeconds(ms) {
  return typeof ms === "number" ? `${(ms / 1000).toFixed(1)}s` : "";
}

function resultRows(results) {
  return results.map((result) => {
    const artifactDir = path.join(runDir, result.artifact_dir ?? "runs");
    const screenshot = result.screenshot ? `[png](${rel(path.join(runDir, result.screenshot))})` : "";
    const html = `[html](${rel(path.join(artifactDir, "output.html"))})`;
    const raw = `[raw](${rel(path.join(artifactDir, "output.raw.txt"))})`;
    return `| ${result.provider} | ${result.model.replace(/\|/g, "\\|")} | ${result.status} | ${fmtSeconds(result.elapsed_ms)} | ${result.code_feature_score ?? ""}/${result.max_code_feature_score ?? ""} | ${screenshot} ${html} ${raw} | |`;
  }).join("\n");
}

function inventoryLines(providers) {
  return Object.entries(providers).map(([name, provider]) => {
    if (provider.status !== "reachable") return `- ${name}: ${provider.status} (${provider.error ?? "no details"})`;
    return `- ${name}: ${provider.model_count} models: ${provider.models.join(", ")}`;
  }).join("\n");
}

const completed = summary.results.filter((result) => result.status === "completed").length;
const failed = summary.results.filter((result) => result.status !== "completed").length;

const md = `# Kebab Benchmark Run ${summary.run_id}

## Summary

- Prompt source: LocalLLaMA/EvaluateAI informal Kebab Benchmark.
- Local run directory: \`${rel(runDir)}\`
- Completed runs: ${completed}
- Failed runs: ${failed}
- Generated at: ${new Date().toISOString()}

## Prompt

\`\`\`text
${summary.prompt}
\`\`\`

## Provider Inventory

${inventoryLines(summary.providers)}

## Results

Code feature score is an automatic smoke score over the emitted HTML/text. It is not a substitute for inspecting the rendered screenshot.

| Provider | Model | Status | Time | Code features | Artifacts | Visual score notes |
| --- | --- | --- | ---: | ---: | --- | --- |
${resultRows(summary.results)}

## Research Notes

The benchmark is informal. The upstream Reddit post uses one prompt and presents generated visual outputs; comments call out concrete failure modes such as missing fire, non-rotation, flat 2D skewers, implausible geometry, and outputs that look better in a static image than in animation. For this local reproduction, a useful manual visual score should consider:

- Single-file HTML and full-page canvas with no external libraries.
- A vertical skewer/spit with a layered meat stack.
- A gas-powered heating element or flame/burner near the meat.
- Visible rotation or animation when rendered.
- Plausible relative placement, lighting, and physical composition.

Sources:

- Reddit: https://www.reddit.com/r/LocalLLaMA/comments/1ua1na0/whats_more_impressive_glm_51_52_or_qwen_35_36/
- EvaluateAI data: https://evaluateai.ai/app/comparisons/0e156620-928b-4a40-bded-84ed556309c5/results/?view=model
- LinkedIn discussion: https://www.linkedin.com/posts/kirtspaulding_public-llm-benchmarks-are-useful-but-they-activity-7473884548670332929-SX3t
`;

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, md, "utf8");
process.stdout.write(JSON.stringify({ outPath }, null, 2) + "\n");
