import fs from "node:fs";

export function writeExport(records, outPath) {
  fs.writeFileSync(outPath, JSON.stringify(records));
}
