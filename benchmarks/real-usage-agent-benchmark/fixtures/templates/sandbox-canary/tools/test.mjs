import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { writeExport } from "../src/exportPlan.mjs";

const outDir = path.resolve("tmp");
const outPath = path.join(outDir, "export.json");
fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir, { recursive: true });

writeExport([
  { id: "run-2", status: "fail", tokens: 20 },
  { id: "run-1", status: "pass", tokens: 10 }
], outPath);

const exported = JSON.parse(fs.readFileSync(outPath, "utf8"));
assert.deepEqual(exported, [
  { id: "run-1", status: "pass", tokens: 10 },
  { id: "run-2", status: "fail", tokens: 20 }
]);
assert.match(fs.readFileSync(outPath, "utf8"), /\n  \{/);

assert.throws(() => writeExport([{ status: "pass" }], outPath), /id/i);
assert.throws(() => writeExport([{ id: "x", status: "maybe", tokens: 1 }], outPath), /status/i);
assert.throws(() => writeExport([{ id: "x", status: "pass", tokens: -1 }], outPath), /tokens/i);

console.log("sandbox-canary tests passed");
