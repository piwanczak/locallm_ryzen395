#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const benchRoot = path.resolve(scriptDir, "..");
const reportsDir = path.join(benchRoot, "reports");

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function inline(text) {
  return escapeHtml(text).replace(/`([^`]+)`/g, "<code>$1</code>");
}

function renderTable(lines) {
  const rows = lines.map((line) => line.trim().replace(/^\||\|$/g, "").split("|").map((cell) => cell.trim()));
  const header = rows[0] ?? [];
  const body = rows.slice(2);
  return `<table><thead><tr>${header.map((cell) => `<th>${inline(cell)}</th>`).join("")}</tr></thead><tbody>${body.map((row) => `<tr>${row.map((cell) => `<td>${inline(cell)}</td>`).join("")}</tr>`).join("")}</tbody></table>`;
}

function renderMarkdown(md) {
  const lines = md.replace(/\r\n/g, "\n").split("\n");
  const out = [];
  let paragraph = [];
  let list = [];
  let code = null;
  let table = [];

  const flushParagraph = () => {
    if (paragraph.length) {
      out.push(`<p>${inline(paragraph.join(" "))}</p>`);
      paragraph = [];
    }
  };
  const flushList = () => {
    if (list.length) {
      out.push(`<ul>${list.map((item) => `<li>${inline(item)}</li>`).join("")}</ul>`);
      list = [];
    }
  };
  const flushTable = () => {
    if (table.length) {
      out.push(renderTable(table));
      table = [];
    }
  };
  const flushBlocks = () => {
    flushParagraph();
    flushList();
    flushTable();
  };

  for (const line of lines) {
    const fence = line.match(/^```(.*)$/);
    if (fence) {
      if (code) {
        out.push(`<pre><code>${escapeHtml(code.lines.join("\n"))}</code></pre>`);
        code = null;
      } else {
        flushBlocks();
        code = { info: fence[1], lines: [] };
      }
      continue;
    }
    if (code) {
      code.lines.push(line);
      continue;
    }

    if (/^\s*$/.test(line)) {
      flushBlocks();
      continue;
    }

    if (/^\|.+\|$/.test(line)) {
      flushParagraph();
      flushList();
      table.push(line);
      continue;
    }
    if (table.length) flushTable();

    const heading = line.match(/^(#{1,6})\s+(.*)$/);
    if (heading) {
      flushBlocks();
      const level = heading[1].length;
      out.push(`<h${level}>${inline(heading[2])}</h${level}>`);
      continue;
    }

    const bullet = line.match(/^\s*-\s+(.*)$/);
    if (bullet) {
      flushParagraph();
      list.push(bullet[1]);
      continue;
    }

    paragraph.push(line.trim());
  }
  if (code) out.push(`<pre><code>${escapeHtml(code.lines.join("\n"))}</code></pre>`);
  flushBlocks();
  return out.join("\n");
}

function titleFromMarkdown(md, fallback) {
  const first = md.match(/^#\s+(.+)$/m);
  return first ? first[1] : fallback;
}

function pageHtml(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <style>
    :root { color-scheme: light dark; }
    body { font-family: "Segoe UI", system-ui, sans-serif; margin: 0; line-height: 1.55; }
    main { max-width: 980px; margin: 0 auto; padding: 32px 20px 56px; }
    h1, h2, h3 { line-height: 1.2; margin-top: 1.4em; }
    h1 { margin-top: 0; }
    code { font-family: Consolas, ui-monospace, monospace; font-size: 0.95em; }
    pre { overflow-x: auto; padding: 14px; border: 1px solid #8884; border-radius: 6px; }
    table { width: 100%; border-collapse: collapse; margin: 1em 0; }
    th, td { border: 1px solid #8885; padding: 7px 9px; vertical-align: top; }
    th { text-align: left; background: #8881; }
    li { margin: 0.2em 0; }
  </style>
</head>
<body>
<main>
${body}
</main>
</body>
</html>
`;
}

function main() {
  fs.mkdirSync(reportsDir, { recursive: true });
  const files = fs.readdirSync(reportsDir)
    .filter((name) => name.endsWith(".md"))
    .sort();
  const rendered = [];
  for (const file of files) {
    const full = path.join(reportsDir, file);
    const md = fs.readFileSync(full, "utf8");
    const title = titleFromMarkdown(md, file);
    const html = pageHtml(title, renderMarkdown(md));
    const out = full.replace(/\.md$/i, ".html");
    fs.writeFileSync(out, html, "utf8");
    rendered.push(path.relative(benchRoot, out).replace(/\\/g, "/"));
  }
  process.stdout.write(JSON.stringify({ reportsDir, rendered }, null, 2) + "\n");
}

main();
