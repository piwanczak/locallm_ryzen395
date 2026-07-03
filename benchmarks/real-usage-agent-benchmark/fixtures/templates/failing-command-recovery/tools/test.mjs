import assert from "node:assert/strict";
import { parseCsvLine } from "../src/parser.mjs";

assert.deepEqual(parseCsvLine("alpha,beta,gamma"), ["alpha", "beta", "gamma"]);
assert.deepEqual(parseCsvLine("alpha,\"beta, gamma\",delta"), ["alpha", "beta, gamma", "delta"]);
assert.deepEqual(parseCsvLine("\"quoted value\",42,\"with spaces\""), ["quoted value", "42", "with spaces"]);
assert.throws(() => parseCsvLine("alpha,\"unterminated"), /quote/i);

console.log("failing-command-recovery tests passed");
