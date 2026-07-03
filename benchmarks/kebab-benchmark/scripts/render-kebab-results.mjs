#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";

const runDir = process.argv[2] ? path.resolve(process.argv[2]) : null;
if (!runDir) {
  console.error("Usage: node scripts/render-kebab-results.mjs <results/run-id>");
  process.exit(1);
}

const chromeCandidates = [
  process.env.CHROME_PATH,
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
].filter(Boolean);

const chromePath = chromeCandidates.find((candidate) => fs.existsSync(candidate));
if (!chromePath) {
  throw new Error("Chrome executable not found. Set CHROME_PATH or install Chrome.");
}

function fileUrl(filePath) {
  return `file:///${filePath.replace(/\\/g, "/").replace(/ /g, "%20")}`;
}

function listRunJsonFiles(root) {
  const runsRoot = path.join(root, "runs");
  if (!fs.existsSync(runsRoot)) return [];
  return fs.readdirSync(runsRoot)
    .map((name) => path.join(runsRoot, name, "run.json"))
    .filter((file) => fs.existsSync(file));
}

function runChrome(args) {
  return new Promise((resolve) => {
    const child = spawn(chromePath, args, { windowsHide: true });
    let stderr = "";
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("close", (code) => resolve({ code, stderr }));
  });
}

const rendered = [];
const profileRoot = path.join(runDir, ".chrome-profile");
fs.mkdirSync(profileRoot, { recursive: true });

for (const runJson of listRunJsonFiles(runDir)) {
  const modelDir = path.dirname(runJson);
  const htmlPath = path.join(modelDir, "output.html");
  const screenshotPath = path.join(modelDir, "screenshot.png");
  const profileDir = path.join(profileRoot, path.basename(modelDir));
  fs.mkdirSync(profileDir, { recursive: true });
  const args = [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    "--allow-file-access-from-files",
    "--run-all-compositor-stages-before-draw",
    "--window-size=1280,800",
    "--virtual-time-budget=5000",
    `--user-data-dir=${profileDir}`,
    `--screenshot=${screenshotPath}`,
    fileUrl(htmlPath),
  ];
  process.stdout.write(`Rendering ${path.relative(runDir, htmlPath)}\n`);
  const result = await runChrome(args);
  const run = JSON.parse(fs.readFileSync(runJson, "utf8"));
  run.screenshot = fs.existsSync(screenshotPath) ? path.relative(runDir, screenshotPath).replace(/\\/g, "/") : null;
  run.render_status = result.code === 0 && run.screenshot ? "rendered" : "failed";
  run.render_stderr = result.stderr.trim().slice(-4000);
  fs.writeFileSync(runJson, JSON.stringify(run, null, 2), "utf8");
  rendered.push({ run: path.relative(runDir, runJson).replace(/\\/g, "/"), screenshot: run.screenshot, status: run.render_status });
}

const summaryPath = path.join(runDir, "summary.json");
if (fs.existsSync(summaryPath)) {
  const summary = JSON.parse(fs.readFileSync(summaryPath, "utf8"));
  const byKey = new Map();
  for (const runJson of listRunJsonFiles(runDir)) {
    const run = JSON.parse(fs.readFileSync(runJson, "utf8"));
    byKey.set(`${run.provider}\0${run.model}`, run);
  }
  summary.results = summary.results.map((result) => byKey.get(`${result.provider}\0${result.model}`) ?? result);
  summary.rendered_at = new Date().toISOString();
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2), "utf8");
}

process.stdout.write(JSON.stringify({ chromePath, rendered }, null, 2) + "\n");
