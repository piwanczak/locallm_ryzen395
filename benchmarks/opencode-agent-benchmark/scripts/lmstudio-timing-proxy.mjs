import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { performance } from "node:perf_hooks";

const listenPort = Number(process.argv[2] ?? "5678");
const targetBase = new URL(process.argv[3] ?? "http://127.0.0.1:1234");
const resultFile = path.resolve(process.argv[4] ?? "results/proxy-events.jsonl");

fs.mkdirSync(path.dirname(resultFile), { recursive: true });

function writeEvent(event) {
  fs.appendFileSync(resultFile, JSON.stringify({ timestamp: new Date().toISOString(), ...event }) + "\n");
}

function collect(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function estimatePromptChars(body) {
  try {
    const json = JSON.parse(body.toString("utf8"));
    const messages = Array.isArray(json.messages) ? json.messages : [];
    const messageText = messages.map((m) => {
      if (typeof m.content === "string") return m.content;
      if (Array.isArray(m.content)) return m.content.map((part) => part.text ?? "").join("\n");
      return "";
    }).join("\n");
    return {
      model: json.model,
      stream: Boolean(json.stream),
      max_tokens: json.max_tokens ?? json.max_completion_tokens ?? null,
      temperature: json.temperature ?? null,
      prompt_chars: messageText.length,
      prompt_token_estimate: Math.round(messageText.length / 3.7)
    };
  } catch {
    return { prompt_chars: null, prompt_token_estimate: null };
  }
}

const server = http.createServer(async (clientReq, clientRes) => {
  const body = await collect(clientReq);
  const started = performance.now();
  const requestMeta = estimatePromptChars(body);
  const requestId = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  let firstByteMs = null;
  let firstTokenMs = null;
  let completionContentChars = 0;
  let rawResponse = "";
  let sseBuffer = "";
  let chunkCount = 0;

  const targetUrl = new URL(clientReq.url ?? "/", targetBase);
  const upstreamReq = http.request({
    protocol: targetUrl.protocol,
    hostname: targetUrl.hostname,
    port: targetUrl.port,
    path: targetUrl.pathname + targetUrl.search,
    method: clientReq.method,
    headers: {
      ...clientReq.headers,
      host: targetUrl.host,
      "content-length": body.length
    }
  }, (upstreamRes) => {
    clientRes.writeHead(upstreamRes.statusCode ?? 502, upstreamRes.headers);
    upstreamRes.on("data", (chunk) => {
      chunkCount += 1;
      if (firstByteMs === null) firstByteMs = performance.now() - started;
      const text = chunk.toString("utf8");
      rawResponse += text;
      sseBuffer += text;
      const lines = sseBuffer.split(/\r?\n/);
      sseBuffer = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.startsWith("data:")) continue;
        const payload = line.slice(5).trim();
        if (!payload || payload === "[DONE]") continue;
        try {
          const json = JSON.parse(payload);
          const content = json.choices?.map((choice) => choice.delta?.content ?? choice.message?.content ?? "").join("") ?? "";
          if (content.length > 0) {
            if (firstTokenMs === null) firstTokenMs = performance.now() - started;
            completionContentChars += content.length;
          }
        } catch {
          // Keep proxying even if a provider emits non-JSON SSE comments.
        }
      }
      clientRes.write(chunk);
    });
    upstreamRes.on("end", () => {
      if (completionContentChars === 0) {
        try {
          const json = JSON.parse(rawResponse);
          const content = json.choices?.map((choice) => choice.message?.content ?? choice.text ?? "").join("") ?? "";
          completionContentChars = content.length;
          if (content.length > 0 && firstTokenMs === null) firstTokenMs = elapsedSince(started);
        } catch {
          completionContentChars = rawResponse.length;
        }
      }
      clientRes.end();
      const elapsedMs = performance.now() - started;
      const decodeWindowSeconds = firstTokenMs === null ? null : Math.max(0.001, (elapsedMs - firstTokenMs) / 1000);
      const estimatedCompletionTokens = Math.round(completionContentChars / 3.7);
      writeEvent({
        request_id: requestId,
        path: clientReq.url,
        status_code: upstreamRes.statusCode,
        elapsed_ms: Number(elapsedMs.toFixed(1)),
        ttft_ms: firstTokenMs === null ? null : Number(firstTokenMs.toFixed(1)),
        first_byte_ms: firstByteMs === null ? null : Number(firstByteMs.toFixed(1)),
        chunk_count: chunkCount,
        completion_content_chars: completionContentChars,
        completion_token_estimate: estimatedCompletionTokens,
        decode_tokens_per_second_estimate: decodeWindowSeconds === null ? null : Number((estimatedCompletionTokens / decodeWindowSeconds).toFixed(2)),
        ...requestMeta
      });
    });
  });

  upstreamReq.on("error", (error) => {
    const elapsedMs = performance.now() - started;
    writeEvent({
      request_id: requestId,
      path: clientReq.url,
      error: error.message,
      elapsed_ms: Number(elapsedMs.toFixed(1)),
      ...requestMeta
    });
    clientRes.writeHead(502, { "content-type": "application/json" });
    clientRes.end(JSON.stringify({ error: error.message }));
  });

  upstreamReq.end(body);
});

function elapsedSince(started) {
  return performance.now() - started;
}

server.listen(listenPort, "127.0.0.1", () => {
  console.log(JSON.stringify({ event: "lmstudio-proxy-listening", port: listenPort, target: targetBase.href, resultFile }));
});

process.on("SIGTERM", () => server.close(() => process.exit(0)));
process.on("SIGINT", () => server.close(() => process.exit(0)));
