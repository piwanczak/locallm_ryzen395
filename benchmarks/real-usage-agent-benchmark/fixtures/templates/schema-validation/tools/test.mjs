import assert from "node:assert/strict";
import { validateConfig } from "../src/validateConfig.mjs";

const input = {
  services: [
    {
      name: "billing",
      endpoint: "https://billing.local/api",
      headers: { "x-client": "local" }
    },
    {
      name: "search",
      endpoint: "http://localhost:9191",
      retries: 1,
      timeoutMs: 2500
    }
  ]
};

const normalized = validateConfig(input);
assert.deepEqual(normalized, {
  mode: "strict",
  services: [
    {
      name: "billing",
      endpoint: "https://billing.local/api",
      retries: 2,
      timeoutMs: 5000,
      headers: { "x-client": "local" }
    },
    {
      name: "search",
      endpoint: "http://localhost:9191",
      retries: 1,
      timeoutMs: 2500,
      headers: {}
    }
  ]
});
assert.equal(input.services[0].retries, undefined, "must not mutate source config");

for (const bad of [
  null,
  { mode: "loose", services: [] },
  { mode: "strict", services: [] },
  { services: [{ name: "a", endpoint: "http://example.com" }] },
  { services: [{ name: "a", endpoint: "https://ok" }, { name: "a", endpoint: "https://ok2" }] },
  { services: [{ name: "a", endpoint: "https://ok", retries: -1 }] },
  { services: [{ name: "a", endpoint: "https://ok", timeoutMs: 99 }] },
  { services: [{ name: "a", endpoint: "https://ok", headers: { token: 42 } }] }
]) {
  assert.throws(() => validateConfig(bad), /config|mode|service|endpoint|duplicate|retry|timeout|header/i);
}

assert.equal(validateConfig({ mode: "audit", services: [{ name: "x", endpoint: "https://x" }] }).mode, "audit");

console.log("schema-validation tests passed");
