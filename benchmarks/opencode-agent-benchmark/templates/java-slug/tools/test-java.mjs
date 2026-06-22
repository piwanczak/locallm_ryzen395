import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const source = fs.readFileSync(path.join(root, "src/main/java/example/Slug.java"), "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(source.includes("class Slug"), "Slug class missing");
assert(source.includes("fromTitle"), "fromTitle method missing");
assert(/toLowerCase\s*\(/.test(source), "slug must lower-case input");
assert(/replaceAll\s*\(\s*"\[\^a-z0-9\]\+"/.test(source), "slug must collapse non-alphanumeric runs");
assert(/replaceAll\s*\(\s*"\^-\|-$"/.test(source) || (/^\s*while\s*\(/m.test(source) && source.includes("startsWith("-")")), "slug must trim leading/trailing hyphens");
assert(!/return\s+normalized\s*;/.test(source), "do not return the untrimmed normalized slug");

const javac = spawnSync("javac", ["-version"], { encoding: "utf8" });
if (javac.status === 0) {
  const build = path.join(root, "build");
  fs.rmSync(build, { recursive: true, force: true });
  fs.mkdirSync(build, { recursive: true });
  const compile = spawnSync("javac", ["-d", build, "src/main/java/example/Slug.java", "src/test/java/example/SlugTest.java"], { cwd: root, encoding: "utf8" });
  if (compile.status !== 0) {
    throw new Error(compile.stderr || compile.stdout || "javac failed");
  }
  const run = spawnSync("java", ["-cp", build, "example.SlugTest"], { cwd: root, encoding: "utf8" });
  if (run.status !== 0) {
    throw new Error(run.stderr || run.stdout || "java test failed");
  }
  console.log("java-slug tests passed with javac");
} else {
  console.log("java-slug source checks passed; javac unavailable on host");
}
