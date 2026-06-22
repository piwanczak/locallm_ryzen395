import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const positional = [];
let targetTokens = 65000;
let sourceMode = "full";
let paddingMode = "distractor";

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--target-tokens") {
    targetTokens = Number(args[++i]);
  } else if (arg.startsWith("--target-tokens=")) {
    targetTokens = Number(arg.slice("--target-tokens=".length));
  } else if (arg === "--source-mode") {
    sourceMode = args[++i];
  } else if (arg.startsWith("--source-mode=")) {
    sourceMode = arg.slice("--source-mode=".length);
  } else if (arg === "--padding-mode") {
    paddingMode = args[++i];
  } else if (arg.startsWith("--padding-mode=")) {
    paddingMode = arg.slice("--padding-mode=".length);
  } else {
    positional.push(arg);
  }
}

const [fixtureDir, taskName, webBaseUrl = ""] = positional;
if (!fixtureDir || !taskName) {
  console.error("usage: node build-prompt.mjs <fixture-dir> <task-name> [web-base-url] [--target-tokens <n>]");
  process.exit(2);
}
if (!Number.isFinite(targetTokens) || targetTokens < 1000) {
  throw new Error(`invalid --target-tokens value: ${targetTokens}`);
}
if (!["full", "thin"].includes(sourceMode)) {
  throw new Error(`invalid --source-mode value: ${sourceMode}`);
}
if (!["distractor", "neutral", "none"].includes(paddingMode)) {
  throw new Error(`invalid --padding-mode value: ${paddingMode}`);
}

const root = path.resolve(fixtureDir);

const taskSpecs = {
  "python-ledger": {
    command: "python tools/test_ledger.py",
    request: "Fix the invoice total calculation so discounts are applied at invoice level before final tax and rounding.",
    inspect: ["README.md", "src/ledger.py", "tools/test_ledger.py"]
  },
  "java-slug": {
    command: "node tools/test-java.mjs",
    request: "Fix the Java slug generator so it trims leading and trailing hyphens after collapsing separators.",
    inspect: ["README.md", "src/main/java/example/Slug.java", "src/test/java/example/SlugTest.java", "tools/test-java.mjs"]
  },
  "js-window": {
    command: "node tools/test.mjs",
    request: "Fix the event window counter so both the start and end boundaries are included.",
    inspect: ["README.md", "src/windowCounter.mjs", "tools/test.mjs"]
  },
  "web-retrieval": {
    command: "node tools/test.mjs",
    request: `Read the local documentation pages from ${webBaseUrl}/ and update answer.json with the stable version, required header, sunset date, and safe endpoint.`,
    inspect: ["README.md", "answer.json", "site/index.html", "site/docs/api.html", "site/docs/archive.html", "site/docs/changelog.html", "tools/test.mjs"]
  },
  "browser-style": {
    command: "node tools/test.mjs",
    request: "Fix the browser-facing filter behavior so matching is case-insensitive and the empty state is correct.",
    inspect: ["README.md", "index.html", "app.js", "tools/test.mjs"]
  }
};

const spec = taskSpecs[taskName];
if (!spec) throw new Error(`unknown task: ${taskName}`);

function listFiles(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === "node_modules" || entry.name === "build" || entry.name === ".git") continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listFiles(full));
    else out.push(full);
  }
  return out;
}

function rel(file) {
  return path.relative(root, file).replace(/\\/g, "/");
}

function readSelected(file) {
  const text = fs.readFileSync(file, "utf8");
  if (text.length > 12000) return text.slice(0, 12000) + "\n[truncated]\n";
  return text;
}

const files = listFiles(root);
const tree = files.map((file) => `- ${rel(file)}`).join("\n");
const selected = files
  .filter((file) => /\.(py|java|js|mjs|json|html|md)$/.test(file))
  .map((file) => `## File: ${rel(file)}\n\n\`\`\`\n${readSelected(file)}\n\`\`\``)
  .join("\n\n");
const inspectList = spec.inspect.map((file) => `- ${file}`).join("\n");

const needles = {
  begin: `BEGIN-FACT-${taskName}: You must only modify files under ${root}.`,
  middle: `MIDDLE-FACT-${taskName}: The verification command is exactly '${spec.command}'.`,
  end: `END-FACT-${taskName}: Do not use live web, package installs, personal browser profiles, or files outside the fixture.`
};

const fillerParagraph = `Distractor project memo: archived migration notes, stale endpoint examples, unrelated refactor ideas, and obsolete benchmark hypotheses. These lines exist only to create a realistic long-context working set. Do not treat them as task requirements. Current task authority remains the sandbox rules, the fixture files, and the verification command.`;
const neutralPaddingParagraph = `Benchmark padding block: this text is intentionally non-authoritative and exists only to measure prompt-processing latency at a controlled input size. Ignore it for implementation decisions. The only authoritative inputs are the task request, sandbox rules, files you inspect in the fixture, and the verification command.`;

function utf8Bytes(text) {
  return Buffer.byteLength(text, "utf8");
}

function makePadding(targetBytes, startIndex) {
  if (paddingMode === "none") {
    return { text: "", nextIndex: startIndex };
  }
  const paragraph = paddingMode === "neutral" ? neutralPaddingParagraph : fillerParagraph;
  const label = paddingMode === "neutral" ? "PADDING" : "FILLER";
  let filler = "";
  let i = startIndex;
  while (utf8Bytes(filler) < targetBytes) {
    i += 1;
    filler += `\n${label}-${String(i).padStart(5, "0")}: ${paragraph} checksum=${(i * 7919) % 100000}.`;
  }
  return { text: filler, nextIndex: i };
}

const sourceSection = sourceMode === "full"
  ? `Selected source, tests, and docs:

${selected}
`
  : `Attachment strategy:

Full fixture contents are intentionally not attached in this run. Inspect only the files you need inside the fixture before editing. Start with these likely files:

${inspectList}
`;

const prefix = `# OpenCode Agent Benchmark Task: ${taskName}

${needles.begin}

You are the benchmark subject. Work only inside this disposable fixture:

${root}

Sandbox rules:

- Do not read or write outside the fixture directory.
- Do not inspect the real journal repository, home directories, credentials, browser profiles, or unrelated files.
- Do not use live web or web search.
- You may use the local documentation server only when the task explicitly gives a localhost URL.
- Do not install packages from the network.
- Preserve unrelated files.
- Run the verification command before finishing.

Windows PowerShell command style:

- Shell commands run in Windows PowerShell.
- OpenCode is already started with the fixture as --dir.
- Do not use Bash-only command syntax.
- Do not use &&.
- The benchmark permission policy denies any shell command containing &&.
- Use one command per shell call when practical.
- Run commands from the fixture root or use the shell tool's workdir option when available.
- If a shell command needs an explicit directory, use: Set-Location -LiteralPath '${root}'; <command>
- To verify this task, prefer exactly: ${spec.command}
- If the shell is not already in the fixture, verify with exactly: Set-Location -LiteralPath '${root}'; ${spec.command}
- Do not wrap the verifier in an extra powershell -Command call.

Task request:

${spec.request}

Verification command:

\`\`\`powershell
${spec.command}
\`\`\`

Repository tree:

${tree}

${sourceSection}
`;

const suffix = `
${needles.end}

Final response format:

- Briefly state what changed.
- State the verification command and whether it passed.
- State whether you touched any files outside the fixture.
`;

const targetBytes = Math.round(targetTokens * 3.7);
const fixedBytes = utf8Bytes(prefix) + utf8Bytes(`\n${needles.middle}\n`) + utf8Bytes(suffix);
const fillerBytes = paddingMode === "none" ? 0 : Math.max(0, targetBytes - fixedBytes);
const firstHalf = makePadding(Math.floor(fillerBytes / 2), 0);
const secondHalf = makePadding(fillerBytes - utf8Bytes(firstHalf.text), firstHalf.nextIndex);

const prompt = `${prefix}${firstHalf.text}
${needles.middle}
${secondHalf.text}${suffix}`;

process.stdout.write(prompt);
