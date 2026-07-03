import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

const node = process.execPath;

function run(args) {
  return spawnSync(node, ["bin/usage-report.mjs", ...args], {
    encoding: "utf8",
    cwd: process.cwd()
  });
}

assert.equal(run([]).stdout.trim(), "runs=4 tokens=9500");
assert.equal(run(["--since", "2026-06-20"]).stdout.trim(), "runs=2 tokens=4900");

const jsonRun = run(["--since", "2026-06-19", "--format", "json"]);
assert.equal(jsonRun.status, 0);
assert.deepEqual(JSON.parse(jsonRun.stdout), {
  runs: 3,
  tokens: 8300,
  byRunner: {
    opencode: 3400,
    pi: 2800,
    api: 2100
  }
});

const bad = run(["--format", "xml"]);
assert.notEqual(bad.status, 0);
assert.match(bad.stderr, /format/i);

console.log("cli-report tests passed");
