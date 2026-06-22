import assert from "node:assert/strict";
import { countEventsInWindow } from "../src/windowCounter.mjs";

const events = [
  { id: "too-early", timestampMs: 99 },
  { id: "start", timestampMs: 100 },
  { id: "middle", timestampMs: 150 },
  { id: "end", timestampMs: 200 },
  { id: "too-late", timestampMs: 201 },
];

assert.equal(countEventsInWindow(events, 100, 200), 3, "window is inclusive on both boundaries");
assert.equal(countEventsInWindow(events, 101, 199), 1, "inner window still works");
assert.throws(() => countEventsInWindow(null, 0, 1), /array/);

console.log("js-window tests passed");
