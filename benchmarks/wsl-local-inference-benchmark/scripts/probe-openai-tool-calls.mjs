#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { performance } from "node:perf_hooks";

function parseArgs(argv) {
  const out = {
    baseUrl: "http://127.0.0.1:8080/v1",
    model: "qwen/qwen3-coder-30b-q4",
    output: "",
    prompt: "Create a file named pi_probe.txt containing exactly PI_TOOL_OK.",
    temperature: 0,
    maxTokens: 512,
    stream: false
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--base-url") out.baseUrl = next, i += 1;
    else if (arg === "--model") out.model = next, i += 1;
    else if (arg === "--output") out.output = next, i += 1;
    else if (arg === "--prompt") out.prompt = next, i += 1;
    else if (arg === "--temperature") out.temperature = Number(next), i += 1;
    else if (arg === "--max-tokens") out.maxTokens = Number(next), i += 1;
    else if (arg === "--stream") out.stream = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return out;
}

async function getJson(url) {
  const response = await fetch(url);
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {}
  return {
    ok: response.ok,
    status: response.status,
    headers: Object.fromEntries(response.headers.entries()),
    text,
    json
  };
}

const args = parseArgs(process.argv.slice(2));
const rootUrl = args.baseUrl.replace(/\/v1\/?$/, "");
const chatUrl = `${args.baseUrl.replace(/\/$/, "")}/chat/completions`;
const propsUrl = `${rootUrl}/props`;
const modelsUrl = `${args.baseUrl.replace(/\/$/, "")}/models`;

const tools = [
  {
    type: "function",
    function: {
      name: "write",
      description: "Write exact text content to a file path in the current workspace.",
      parameters: {
        type: "object",
        additionalProperties: false,
        required: ["path", "content"],
        properties: {
          path: {
            type: "string",
            description: "Workspace-relative or absolute file path."
          },
          content: {
            type: "string",
            description: "Exact text content to write."
          }
        }
      }
    }
  }
];

const requestBody = {
  model: args.model,
  messages: [
    {
      role: "system",
      content: "Use the provided write tool when the user asks you to create a file. Do not answer in prose when a tool is appropriate."
    },
    {
      role: "user",
      content: args.prompt
    }
  ],
  tools,
  tool_choice: "auto",
  temperature: args.temperature,
  max_tokens: args.maxTokens,
  stream: args.stream
};

const started = performance.now();
const [models, props] = await Promise.all([
  getJson(modelsUrl),
  getJson(propsUrl)
]);

const response = await fetch(chatUrl, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify(requestBody)
});
let responseText = "";
let responseJson = null;
const streamEvents = [];
const streamToolCallDeltas = [];

if (args.stream) {
  responseText = await response.text();
  for (const block of responseText.split(/\r?\n\r?\n/)) {
    const dataLines = block
      .split(/\r?\n/)
      .filter((line) => line.startsWith("data: "))
      .map((line) => line.slice("data: ".length));
    for (const data of dataLines) {
      if (data === "[DONE]") {
        streamEvents.push({ done: true });
        continue;
      }
      try {
        const event = JSON.parse(data);
        streamEvents.push(event);
        const deltas = event?.choices?.[0]?.delta?.tool_calls;
        if (Array.isArray(deltas)) {
          streamToolCallDeltas.push(...deltas);
        }
      } catch {
        streamEvents.push({ parseError: true, data });
      }
    }
  }
} else {
  responseText = await response.text();
  try {
    responseJson = responseText ? JSON.parse(responseText) : null;
  } catch {}
}

const choice = responseJson?.choices?.[0] ?? null;
const message = choice?.message ?? null;
const toolCalls = message?.tool_calls ?? null;
const result = {
  createdAt: new Date().toISOString(),
  baseUrl: args.baseUrl,
  model: args.model,
  elapsedMs: Math.round((performance.now() - started) * 10) / 10,
  props: {
    ok: props.ok,
    status: props.status,
    chatTemplatePresent: Boolean(props.json?.chat_template),
    chatTemplateToolUsePresent: Boolean(props.json?.chat_template_tool_use),
    chatFormat: props.json?.chat_format ?? props.json?.default_generation_settings?.chat_format ?? null,
    raw: props.json ?? props.text
  },
  models: {
    ok: models.ok,
    status: models.status,
    raw: models.json ?? models.text
  },
  request: requestBody,
  response: {
    ok: response.ok,
    status: response.status,
    headers: Object.fromEntries(response.headers.entries()),
    text: responseText,
    json: responseJson,
    streamEvents,
    streamToolCallDeltas
  },
  classification: {
    structuredToolCalls: args.stream
      ? streamToolCallDeltas.length > 0
      : Array.isArray(toolCalls) && toolCalls.length > 0,
    finishReason: choice?.finish_reason ?? null,
    assistantContentType: typeof message?.content,
    assistantContentPreview: typeof message?.content === "string" ? message.content.slice(0, 1000) : message?.content ?? null,
    toolCalls,
    streamToolCallDeltas
  }
};

if (args.output) {
  await fs.mkdir(path.dirname(args.output), { recursive: true });
  await fs.writeFile(args.output, `${JSON.stringify(result, null, 2)}\n`, "utf8");
}

console.log(JSON.stringify(result.classification, null, 2));
if (!result.classification.structuredToolCalls) {
  process.exitCode = 2;
}
