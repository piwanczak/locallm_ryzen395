import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";

const [,, fixtureDir, taskName, manifestBeforeFile, resultFile] = process.argv;
if (!fixtureDir || !taskName || !manifestBeforeFile || !resultFile) {
  console.error("usage: node grade-run.mjs <fixture-dir> <task-name> <manifest-before.json> <result-json>");
  process.exit(2);
}

const root = path.resolve(fixtureDir);

function listFiles(dir) {
  const out = {};
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      Object.assign(out, listFiles(full));
    } else {
      const rel = path.relative(root, full).replace(/\\/g, "/");
      const stat = fs.statSync(full);
      out[rel] = { size: stat.size, mtimeMs: Math.round(stat.mtimeMs), sha1: sha1(full) };
    }
  }
  return out;
}

function sha1(file) {
  return crypto.createHash("sha1").update(fs.readFileSync(file)).digest("hex");
}

function run(command) {
  const shell = process.platform === "win32" ? "powershell.exe" : "bash";
  const args = process.platform === "win32"
    ? ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command]
    : ["-lc", command];
  const started = Date.now();
  const child = spawnSync(shell, args, {
    cwd: root,
    encoding: "utf8",
    timeout: 120000,
    env: { ...process.env }
  });
  return {
    command,
    exitCode: child.status,
    elapsedMs: Date.now() - started,
    stdout: child.stdout,
    stderr: child.stderr,
    timedOut: Boolean(child.error && child.error.code === "ETIMEDOUT")
  };
}

const commands = {
  "python-ledger": "python tools/test_ledger.py",
  "java-slug": "node tools/test-java.mjs",
  "js-window": "node tools/test.mjs",
  "web-retrieval": "node tools/test.mjs",
  "browser-style": "node tools/test.mjs"
};

const before = JSON.parse(fs.readFileSync(manifestBeforeFile, "utf8"));
const after = listFiles(root);
const modified = [];
for (const [file, meta] of Object.entries(after)) {
  if (!before[file] || before[file].sha1 !== meta.sha1) modified.push(file);
}
for (const file of Object.keys(before)) {
  if (!after[file]) modified.push(`${file} (deleted)`);
}

const verification = run(commands[taskName]);
const grade = {
  fixtureDir: root,
  taskName,
  modifiedFiles: modified.sort(),
  verification,
  passed: verification.exitCode === 0 && !verification.timedOut
};

fs.writeFileSync(resultFile, JSON.stringify(grade, null, 2) + "\n", "utf8");
process.stdout.write(JSON.stringify(grade, null, 2));
