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
const empty = new Element("No matching runs");
const runs = [
  new Element("QWEN nightly pass", { owner: "Core Team" }),
  new Element("gemma browser diagnosis", { owner: "Gemma Bench" }),
  new Element("static docs update", { owner: "Tools" }),
];

const document = {
  querySelector(selector) {
    if (selector === "#filter") return filter;
    if (selector === "#empty") return empty;
    throw new Error("unexpected selector " + selector);
  },
  querySelectorAll(selector) {
    if (selector === "#runs li") return runs;
    throw new Error("unexpected selectorAll " + selector);
  },
};

vm.runInNewContext(script, { document, Array });

filter.value = "gemma";
filter.dispatch("input");
assert.equal(runs[1].hidden, false, "lowercase query should match Gemma run");
assert.equal(runs[0].hidden, true);

filter.value = "CORE";
filter.dispatch("input");
assert.equal(runs[0].hidden, false, "uppercase query should match owner case-insensitively");
assert.equal(runs[1].hidden, true);

filter.value = "missing";
filter.dispatch("input");
assert.equal(empty.hidden, false, "empty state should show when no runs match");

console.log("browser-style tests passed");
