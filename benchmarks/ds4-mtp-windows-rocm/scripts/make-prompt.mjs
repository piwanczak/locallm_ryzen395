import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const outputPath = resolve(
  process.argv[2] ??
    "benchmarks/ds4-mtp-windows-rocm/prompts/repeated-english-ctx1024.txt",
);

const lines = [];
for (let i = 0; i < 160; i += 1) {
  lines.push(
    `Segment ${String(i).padStart(3, "0")}: Measure deterministic local inference throughput with a fixed prompt. The quick brown fox packs vectors, kernels, cache rows, routed experts, and decode tokens into a repeatable benchmark sentence.`,
  );
}

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${lines.join("\n")}\n`, "utf8");
console.log(outputPath);
