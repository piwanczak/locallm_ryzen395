import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const script = fs.readFileSync("app.js", "utf8");

class Element {
  constructor(text = "", dataset = {}) {
    this.textContent = text;
    this.dataset = dataset;
    this.hidden = false;
    this.value = "";
    this.listeners = {};
  }
  addEventListener(name, fn) {
    this.listeners[name] = fn;
  }
  dispatch(name) {
    this.listeners[name]?.();
  }
}

const filter = new Element();
const count = new Element();
const empty = new Element("No matching runs");
const rows = [
  new Element("Qwen nightly pass", { owner: "Core Team", status: "pass" }),
  new Element("Gemma browser diagnosis", { owner: "Gemma Bench", status: "fail" }),
  new Element("Static docs update", { owner: "Tools", status: "pass" })
];

const document = {
  querySelector(selector) {
    if (selector === "#filter") return filter;
    if (selector === "#count") return count;
    if (selector === "#empty") return empty;
    throw new Error(`unexpected selector ${selector}`);
  },
  querySelectorAll(selector) {
    if (selector === "#runs tr") return rows;
    throw new Error(`unexpected selectorAll ${selector}`);
  }
};

vm.runInNewContext(script, { document, Array });

filter.value = "gemma";
filter.dispatch("input");
assert.equal(rows[1].hidden, false, "lowercase query should match Gemma title");
assert.equal(rows[0].hidden, true);
assert.equal(count.textContent, "1 visible");

filter.value = "CORE";
filter.dispatch("input");
assert.equal(rows[0].hidden, false, "uppercase query should match owner case-insensitively");
assert.equal(rows[1].hidden, true);

filter.value = "fail";
filter.dispatch("input");
assert.equal(rows[1].hidden, false, "query should match status text");
assert.equal(count.textContent, "1 visible");

filter.value = "missing";
filter.dispatch("input");
assert.equal(empty.hidden, false, "empty state should show when no rows match");
assert.equal(count.textContent, "0 visible");

assert.match(script, /empty\.hidden = visible !== 0;/, "preserve empty-state hidden semantics");

console.log("frontend-filter tests passed");
