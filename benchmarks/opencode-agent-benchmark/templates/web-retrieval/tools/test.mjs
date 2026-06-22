import fs from "node:fs";
import assert from "node:assert/strict";

const answer = JSON.parse(fs.readFileSync("answer.json", "utf8"));
assert.equal(answer.stableVersion, "2026-05-17");
assert.equal(answer.requiredHeader, "X-Acorn-Safety: strict");
assert.equal(answer.sunsetDate, "2026-09-30");
assert.equal(answer.safeEndpoint, "/v2/invoices/preview");
console.log("web-retrieval tests passed");
