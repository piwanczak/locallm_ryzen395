import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function write(file, content) {
  const target = path.join(root, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content.replace(/\n/g, "\r\n"), "utf8");
}

function writeJson(file, value) {
  write(file, JSON.stringify(value, null, 2) + "\n");
}

function mkdir(dir) {
  fs.mkdirSync(path.join(root, dir), { recursive: true });
}

function cleanGenerated() {
  for (const rel of ["templates", "fixtures", "prompts", "results", ".xdg-config", ".xdg-data", ".xdg-cache", ".xdg-state", ".tmp"]) {
    fs.rmSync(path.join(root, rel), { recursive: true, force: true });
  }
  for (const rel of ["templates", "fixtures", "prompts", "results", "logs"]) {
    mkdir(rel);
  }
}

function commonPackageScripts() {
  return {
    "test": "node tools/test.mjs"
  };
}

function setupPythonTemplate() {
  write("templates/python-ledger/README.md", `# Python Ledger Fixture

Task: fix the invoice total calculation in \`src/ledger.py\`.

Run:

\`\`\`powershell
python tools/test_ledger.py
\`\`\`
`);

  write("templates/python-ledger/src/ledger.py", `from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP


@dataclass(frozen=True)
class LineItem:
    sku: str
    quantity: int
    unit_price: Decimal


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def invoice_total(items: list[LineItem], discount_percent: Decimal, tax_percent: Decimal) -> Decimal:
    """Return the final invoice total after one invoice-level discount and tax."""
    subtotal = Decimal("0.00")
    for item in items:
        line_total = item.unit_price * item.quantity
        discounted_line = line_total * (Decimal("1.00") - discount_percent / Decimal("100"))
        subtotal += _money(discounted_line)

    with_tax = subtotal * (Decimal("1.00") + tax_percent / Decimal("100"))
    return _money(with_tax)
`);

  write("templates/python-ledger/tools/test_ledger.py", `import pathlib
import sys
from decimal import Decimal

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ledger import LineItem, invoice_total


def check(name, actual, expected):
    if actual != expected:
        raise AssertionError(f"{name}: expected {expected}, got {actual}")


items = [
    LineItem("A-100", 3, Decimal("19.995")),
    LineItem("B-205", 2, Decimal("4.335")),
    LineItem("C-900", 1, Decimal("199.99")),
]

check(
    "invoice-level rounding",
    invoice_total(items, Decimal("12.5"), Decimal("8.25")),
    Decimal("254.11"),
)

check(
    "zero discount",
    invoice_total([LineItem("Z", 7, Decimal("0.99"))], Decimal("0"), Decimal("0")),
    Decimal("6.93"),
)

check(
    "fractional unit prices",
    invoice_total([LineItem("F", 3, Decimal("0.335"))], Decimal("10"), Decimal("0")),
    Decimal("0.90"),
)

print("python-ledger tests passed")
`);
}

function setupJavaTemplate() {
  write("templates/java-slug/README.md", `# Java Slug Fixture

Task: fix \`src/main/java/example/Slug.java\`.

Run:

\`\`\`powershell
node tools/test-java.mjs
\`\`\`

The host currently has no JDK in PATH. The test command performs deterministic Java-source checks and uses \`javac\` automatically if it is available.
`);

  write("templates/java-slug/src/main/java/example/Slug.java", `package example;

public final class Slug {
    private Slug() {
    }

    public static String fromTitle(String title) {
        if (title == null) {
            throw new IllegalArgumentException("title is required");
        }

        String normalized = title.trim().toLowerCase();
        normalized = normalized.replaceAll("[^a-z0-9]+", "-");
        return normalized;
    }
}
`);

  write("templates/java-slug/src/test/java/example/SlugTest.java", `package example;

public final class SlugTest {
    public static void main(String[] args) {
        expect("hello-world", Slug.fromTitle(" Hello, World! "));
        expect("api-v2-release", Slug.fromTitle("API v2: release"));
        expect("edge-case", Slug.fromTitle("---Edge---Case---"));
    }

    private static void expect(String expected, String actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " but got " + actual);
        }
    }
}
`);

  write("templates/java-slug/tools/test-java.mjs", `import fs from "node:fs";
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
assert(/toLowerCase\\s*\\(/.test(source), "slug must lower-case input");
assert(/replaceAll\\s*\\(\\s*"\\[\\^a-z0-9\\]\\+"/.test(source), "slug must collapse non-alphanumeric runs");
assert(/replaceAll\\s*\\(\\s*"\\^-\\|-\$"/.test(source) || (/^\\s*while\\s*\\(/m.test(source) && source.includes("startsWith(\"-\")")), "slug must trim leading/trailing hyphens");
assert(!/return\\s+normalized\\s*;/.test(source), "do not return the untrimmed normalized slug");

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
`);
}

function setupJsTemplate() {
  writeJson("templates/js-window/package.json", {
    scripts: commonPackageScripts(),
    type: "module"
  });

  write("templates/js-window/README.md", `# JavaScript Window Counter Fixture

Task: fix \`src/windowCounter.mjs\`.

Run:

\`\`\`powershell
node tools/test.mjs
\`\`\`
`);

  write("templates/js-window/src/windowCounter.mjs", `export function countEventsInWindow(events, startMs, endMs) {
  if (!Array.isArray(events)) {
    throw new TypeError("events must be an array");
  }

  return events.filter((event) => {
    return event.timestampMs > startMs && event.timestampMs < endMs;
  }).length;
}
`);

  write("templates/js-window/tools/test.mjs", `import assert from "node:assert/strict";
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
`);
}

function setupWebRetrievalTemplate() {
  writeJson("templates/web-retrieval/package.json", {
    scripts: commonPackageScripts(),
    type: "module"
  });

  write("templates/web-retrieval/README.md", `# Web Retrieval Fixture

Task: read the local documentation server and fill \`answer.json\`.

Run:

\`\`\`powershell
node tools/test.mjs
\`\`\`
`);

  writeJson("templates/web-retrieval/answer.json", {
    stableVersion: "",
    requiredHeader: "",
    sunsetDate: "",
    safeEndpoint: ""
  });

  write("templates/web-retrieval/site/index.html", `<!doctype html>
<html>
<head><title>Acorn API Docs</title></head>
<body>
  <h1>Acorn API Docs</h1>
  <nav>
    <a href="/docs/api.html">API</a>
    <a href="/docs/changelog.html">Changelog</a>
    <a href="/docs/archive.html">Archive</a>
  </nav>
</body>
</html>
`);

  write("templates/web-retrieval/site/docs/api.html", `<!doctype html>
<html>
<head><title>API</title></head>
<body>
  <h1>API Reference</h1>
  <p>The stable API version is <strong>2026-05-17</strong>.</p>
  <p>Use request header <code>X-Acorn-Safety: strict</code> for write previews.</p>
  <p>The safe endpoint for previewing invoices is <code>/v2/invoices/preview</code>.</p>
  <p>Distractor: old endpoint <code>/v1/previewInvoice</code> is not safe for new clients.</p>
</body>
</html>
`);

  write("templates/web-retrieval/site/docs/changelog.html", `<!doctype html>
<html>
<head><title>Changelog</title></head>
<body>
  <h1>Changelog</h1>
  <article>
    <h2>2026-06-01</h2>
    <p>The legacy invoice preview endpoint will be sunset on <time datetime="2026-09-30">September 30, 2026</time>.</p>
  </article>
  <article>
    <h2>2025-12-12</h2>
    <p>Distractor: beta header <code>X-Acorn-Experimental</code> was removed.</p>
  </article>
</body>
</html>
`);

  write("templates/web-retrieval/site/docs/archive.html", `<!doctype html>
<html>
<head><title>Archive</title></head>
<body>
  <h1>Archived Docs</h1>
  <p>Deprecated version 2024-11-01 used <code>X-Acorn-Safety: relaxed</code>.</p>
  <p>This page is intentionally stale.</p>
</body>
</html>
`);

  write("templates/web-retrieval/tools/test.mjs", `import fs from "node:fs";
import assert from "node:assert/strict";

const answer = JSON.parse(fs.readFileSync("answer.json", "utf8"));
assert.equal(answer.stableVersion, "2026-05-17");
assert.equal(answer.requiredHeader, "X-Acorn-Safety: strict");
assert.equal(answer.sunsetDate, "2026-09-30");
assert.equal(answer.safeEndpoint, "/v2/invoices/preview");
console.log("web-retrieval tests passed");
`);
}

function setupBrowserTemplate() {
  writeJson("templates/browser-style/package.json", {
    scripts: commonPackageScripts(),
    type: "module"
  });

  write("templates/browser-style/README.md", `# Browser-Style Fixture

Task: fix the local UI behavior in \`app.js\`.

Run:

\`\`\`powershell
node tools/test.mjs
\`\`\`

The test command executes the browser-facing script in a tiny DOM harness so the agent can verify UI behavior without using a personal browser profile.
`);

  write("templates/browser-style/index.html", `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Run Queue</title>
</head>
<body>
  <label for="filter">Filter runs</label>
  <input id="filter" type="search" value="">
  <ul id="runs">
    <li data-owner="Core Team">QWEN nightly pass</li>
    <li data-owner="Gemma Bench">gemma browser diagnosis</li>
    <li data-owner="Tools">static docs update</li>
  </ul>
  <p id="empty" hidden>No matching runs</p>
  <script src="./app.js"></script>
</body>
</html>
`);

  write("templates/browser-style/app.js", `const filter = document.querySelector("#filter");
const runs = Array.from(document.querySelectorAll("#runs li"));
const empty = document.querySelector("#empty");

function applyFilter() {
  const query = filter.value.trim();
  let visible = 0;

  for (const run of runs) {
    const haystack = \`\${run.textContent} \${run.dataset.owner}\`;
    const match = haystack.includes(query);
    run.hidden = !match;
    if (match) visible += 1;
  }

  empty.hidden = visible !== 0;
}

filter.addEventListener("input", applyFilter);
applyFilter();
`);

  write("templates/browser-style/tools/test.mjs", `import fs from "node:fs";
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
`);
}

function setupConfig() {
  writeJson("opencode-benchmark.config.json", {
    "$schema": "https://opencode.ai/config.json",
    "provider": {
      "lmstudio": {
        "npm": "@ai-sdk/openai-compatible",
        "name": "LM Studio timing proxy",
        "options": {
          "baseURL": "http://127.0.0.1:5678/v1",
          "apiKey": "lmstudio"
        },
        "models": {
          "qwen/qwen3-coder-30b": {
            "name": "Qwen3 Coder 30B local",
            "limit": {
              "context": 65536,
              "output": 4096
            }
          },
          "google/gemma-4-e4b": {
            "name": "Gemma 4 E4B local",
            "limit": {
              "context": 65536,
              "output": 4096
            }
          }
        }
      }
    },
    "model": "lmstudio/qwen/qwen3-coder-30b",
    "small_model": "lmstudio/qwen/qwen3-coder-30b",
    "permission": {
      "*": "allow",
      "external_directory": "deny",
      "websearch": "deny",
      "question": "deny",
      "bash": {
        "*": "allow",
        "rm *": "deny",
        "rm -rf *": "deny",
        "del *": "deny",
        "erase *": "deny",
        "Remove-Item *": "deny",
        "git commit *": "deny",
        "git push *": "deny",
        "npm install *": "deny",
        "pnpm install *": "deny",
        "yarn add *": "deny"
      }
    },
    "share": "disabled",
    "autoupdate": false
  });
}

function setupDocs() {
  write("README.md", `# OpenCode Agent Benchmark

Disposable benchmark workspace for comparing local LM Studio models under OpenCode.

Key safety choices:

- OpenCode is run with \`--dir\` pointing at copied fixture workspaces under \`fixtures/work\`.
- XDG config/data/cache/state and temp paths are redirected into this benchmark directory.
- The benchmark config denies \`external_directory\`, \`websearch\`, user questions, destructive shell patterns, and package installs.
- The LM Studio timing proxy only forwards to \`http://127.0.0.1:1234\`.
- Each run is graded from fixture-local files and a before/after manifest.

Run order:

\`\`\`powershell
node scripts/setup-benchmark.mjs
.\\scripts\\reset-fixtures.ps1
.\\scripts\\run-opencode-benchmark.ps1 -Profile gemma-65k -Tasks python-ledger
\`\`\`
`);

  write("docs/sandbox-boundary.md", `# Sandbox Boundary

This benchmark uses an application-level disposable sandbox, not a kernel or VM boundary.

Boundary controls:

- Fixture working directories are copied from \`templates/\` into \`fixtures/work/<run-id>/\`.
- OpenCode receives \`--dir <fixture-workdir>\` for each task.
- \`OPENCODE_CONFIG\`, \`OPENCODE_CONFIG_DIR\`, \`XDG_CONFIG_HOME\`, \`XDG_DATA_HOME\`, \`XDG_CACHE_HOME\`, \`XDG_STATE_HOME\`, \`TEMP\`, and \`TMP\` point under this benchmark root.
- OpenCode config sets \`permission.external_directory = deny\`.
- OpenCode config denies \`websearch\`, package installs, git commit/push, and common destructive shell commands.
- The local web retrieval fixture serves static files from the fixture only.
- The timing proxy forwards only to local LM Studio at \`127.0.0.1:1234\`.

Verification:

- The runner records resolved OpenCode paths before runs.
- Each run records a manifest of files before and after the agent.
- The grader reports files modified outside the task workspace, if any.
- A canary file is placed under \`fixtures/canary/outside-fixture-canary.txt\`; it must remain unchanged.

Residual risk:

OpenCode permissions are not an operating-system sandbox. The benchmark therefore avoids real project repos, personal browser sessions, real credentials, and live websites, and treats all model-driven runs as disposable.
`);
}

cleanGenerated();
setupPythonTemplate();
setupJavaTemplate();
setupJsTemplate();
setupWebRetrievalTemplate();
setupBrowserTemplate();
setupConfig();
setupDocs();
write("fixtures/canary/outside-fixture-canary.txt", "CANARY: OpenCode benchmark agents must not read or modify this file.\n");
console.log(`benchmark scaffold generated at ${root}`);
