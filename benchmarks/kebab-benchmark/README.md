# Kebab Benchmark

This project reproduces the informal LocalLLaMA/EvaluateAI "Kebab Benchmark" prompt against local inference endpoints.

The benchmark is a visual code-generation task, not an official packaged suite. Models are asked to write a single HTML file with a full-page canvas and no libraries that simulates a realistic vertical Döner kebab skewer rotating in front of a gas powered heating element. The generated HTML is saved, rendered with headless Chrome, and summarized for visual inspection.

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

## Structure

```text
benchmarks/kebab-benchmark/
|-- README.md
|-- scripts/
|-- prompts/
|-- results/   # local-only raw outputs and screenshots
`-- reports/   # durable Markdown reports; generated HTML is local-only
```

## Typical Commands

Run all currently reachable default providers:

```powershell
node .\benchmarks\kebab-benchmark\scripts\run-kebab-benchmark.mjs --providers lmstudio,ollama-windows,ollama-wsl
```

Render screenshots for a run directory:

```powershell
node .\benchmarks\kebab-benchmark\scripts\render-kebab-results.mjs .\benchmarks\kebab-benchmark\results\<run-id>
```

Create a Markdown rollup from a run directory:

```powershell
node .\benchmarks\kebab-benchmark\scripts\summarize-kebab-results.mjs .\benchmarks\kebab-benchmark\results\<run-id> --out .\benchmarks\kebab-benchmark\reports\<report-name>.md
node .\benchmarks\kebab-benchmark\scripts\render-markdown-reports.mjs
```
