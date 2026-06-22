import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [,, dir, output] = process.argv;
if (!dir || !output) {
  console.error("usage: node write-manifest.mjs <dir> <output>");
  process.exit(2);
}

const root = path.resolve(dir);
const manifest = {};

function walk(current) {
  for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
    const full = path.join(current, entry.name);
    if (entry.isDirectory()) {
      walk(full);
    } else {
      const rel = path.relative(root, full).replace(/\\/g, "/");
      const stat = fs.statSync(full);
      manifest[rel] = {
        size: stat.size,
        mtimeMs: Math.round(stat.mtimeMs),
        sha1: crypto.createHash("sha1").update(fs.readFileSync(full)).digest("hex")
      };
    }
  }
}

walk(root);
fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
fs.writeFileSync(output, JSON.stringify(manifest, null, 2) + "\n", "utf8");
