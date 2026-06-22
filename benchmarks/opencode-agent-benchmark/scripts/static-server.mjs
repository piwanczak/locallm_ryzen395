import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.argv[2] ?? ".");
const port = Number(process.argv[3] ?? "8765");

function contentType(file) {
  if (file.endsWith(".html")) return "text/html; charset=utf-8";
  if (file.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (file.endsWith(".json")) return "application/json; charset=utf-8";
  if (file.endsWith(".css")) return "text/css; charset=utf-8";
  return "text/plain; charset=utf-8";
}

function safePath(urlPath) {
  const decoded = decodeURIComponent(urlPath.split("?")[0]);
  const rel = decoded === "/" ? "index.html" : decoded.replace(/^\/+/, "");
  const target = path.resolve(root, rel);
  if (!target.startsWith(root)) return null;
  return target;
}

const server = http.createServer((req, res) => {
  const target = safePath(req.url ?? "/");
  if (!target) {
    res.writeHead(403);
    res.end("forbidden");
    return;
  }

  fs.readFile(target, (err, body) => {
    if (err) {
      res.writeHead(404);
      res.end("not found");
      return;
    }
    res.writeHead(200, { "content-type": contentType(target), "cache-control": "no-store" });
    res.end(body);
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log(JSON.stringify({ event: "static-server-listening", root, port, url: `http://127.0.0.1:${port}` }));
});

process.on("SIGTERM", () => server.close(() => process.exit(0)));
process.on("SIGINT", () => server.close(() => process.exit(0)));
