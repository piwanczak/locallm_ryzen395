#!/usr/bin/env node
import fs from "node:fs";

function parseArgs(argv) {
  const args = { input: "fixtures/usage.csv" };
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === "--input") {
      i += 1;
      args.input = argv[i];
    }
  }
  return args;
}

function parseCsv(text) {
  const [headerLine, ...lines] = text.trim().split(/\r?\n/);
  const headers = headerLine.split(",");
  return lines.map((line) => {
    const values = line.split(",");
    return Object.fromEntries(headers.map((header, index) => [header, values[index]]));
  });
}

function main() {
  const args = parseArgs(process.argv);
  const rows = parseCsv(fs.readFileSync(args.input, "utf8"));
  const totalTokens = rows.reduce((sum, row) => sum + Number(row.tokens), 0);
  console.log(`runs=${rows.length} tokens=${totalTokens}`);
}

main();
