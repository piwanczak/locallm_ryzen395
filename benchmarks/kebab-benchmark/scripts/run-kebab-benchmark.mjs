#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const benchRoot = path.resolve(scriptDir, "..");
const resultsRoot = path.join(benchRoot, "results");

const PROMPT = "Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.";

const DEFAULT_PROVIDERS = {
  lmstudio: {
    name: "lmstudio",
    kind: "openai",
    baseUrl: "http://127.0.0.1:1234/v1",
    modelsUrl: "http://127.0.0.1:1234/v1/models",
  },
  "ollama-windows": {
    name: "ollama-windows",
    kind: "ollama",
    baseUrl: "http://127.0.0.1:11434",
    modelsUrl: "http://127.0.0.1:11434/api/tags",
  },
  "ollama-wsl": {
    name: "ollama-wsl",
    kind: "ollama",
    baseUrl: "http://127.0.0.1:11435",
    modelsUrl: "http://127.0.0.1:11435/api/tags",
  },
};

function parseArgs(argv) {
  const args = {
    providers: "lmstudio,ollama-windows,ollama-wsl",
    models: "",
    runId: timestampId(),
    maxTokens: 8192,
    timeoutSeconds: 1800,
    temperature: 1,
    topP: 0.95,
    contextLength: 0,
    think: "default",
    ollamaApi: "generate",
    promptExtra: "",
    keepAlive: "10m",
    openaiProvider: "",
    openaiBaseUrl: "",
    openaiModelsUrl: "",
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const value = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : "true";
    if (key === "max-tokens") args.maxTokens = Number(value);
    else if (key === "timeout-seconds") args.timeoutSeconds = Number(value);
    else if (key === "top-p") args.topP = Number(value);
    else if (key === "temperature") args.temperature = Number(value);
    else if (key === "context-length") args.contextLength = Number(value);
    else if (key === "think") args.think = value;
    else if (key === "ollama-api") args.ollamaApi = value;
    else if (key === "prompt-extra") args.promptExtra = value;
    else if (key === "run-id") args.runId = value;
    else if (key === "providers") args.providers = value;
    else if (key === "models") args.models = value;
    else if (key === "keep-alive") args.keepAlive = value;
    else if (key === "openai-provider") args.openaiProvider = value;
    else if (key === "openai-base-url") args.openaiBaseUrl = value;
    else if (key === "openai-models-url") args.openaiModelsUrl = value;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return args;
}

function buildPrompt(args) {
  const extra = String(args.promptExtra ?? "").trim();
  return extra ? `${PROMPT}\n\n${extra}` : PROMPT;
}

function timestampId() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function safeName(value) {
  return String(value).replace(/[^a-zA-Z0-9_.-]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 120);
}

function stripReasoningTrace(text) {
  const value = String(text ?? "").trim();
  const closeTag = value.search(/<\/think>/i);
  if (closeTag < 0) return value;
  const after = value.slice(closeTag).replace(/^<\/think>\s*/i, "").trim();
  return after || value;
}

async function fetchJson(url, options = {}, timeoutSeconds = 30) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutSeconds * 1000);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = { raw: text };
    }
    if (!res.ok) {
      const err = new Error(`HTTP ${res.status} ${res.statusText} for ${url}`);
      err.data = data;
      throw err;
    }
    return data;
  } finally {
    clearTimeout(timeout);
  }
}

async function listModels(provider) {
  if (provider.kind === "openai") {
    const data = await fetchJson(provider.modelsUrl, {}, 10);
    return (data.data ?? [])
      .map((model) => ({
        id: model.id,
        label: model.id,
        raw: model,
      }))
      .filter((model) => !/embedding/i.test(model.id));
  }
  if (provider.kind === "ollama") {
    const data = await fetchJson(provider.modelsUrl, {}, 10);
    return (data.models ?? []).map((model) => ({
      id: model.model || model.name,
      label: model.name || model.model,
      raw: model,
    }));
  }
  throw new Error(`Unsupported provider kind: ${provider.kind}`);
}

function selectModels(models, filter) {
  if (!filter) return models;
  const wanted = filter.split(",").map((item) => item.trim()).filter(Boolean);
  const selected = [];
  for (const item of wanted) {
    for (const model of models) {
      const matches = model.id === item || model.label === item || model.id.includes(item);
      if (matches && !selected.some((existing) => existing.id === model.id)) selected.push(model);
    }
  }
  return selected;
}

async function runOpenAI(provider, model, args) {
  const prompt = buildPrompt(args);
  const body = {
    model: model.id,
    messages: [{ role: "user", content: prompt }],
    temperature: args.temperature,
    top_p: args.topP,
    max_tokens: args.maxTokens,
  };
  const started = performance.now();
  const data = await fetchJson(`${provider.baseUrl.replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }, args.timeoutSeconds);
  const elapsedMs = Math.round(performance.now() - started);
  const message = data.choices?.[0]?.message ?? {};
  return {
    provider: provider.name,
    model: model.id,
    status: "completed",
    elapsed_ms: elapsedMs,
    prompt,
    request: body,
    response: data,
    output: [message.reasoning_content, message.content].filter(Boolean).join("\n\n"),
    usage: data.usage ?? null,
  };
}

async function runOllama(provider, model, args) {
  if (args.ollamaApi === "chat") return runOllamaChat(provider, model, args);
  if (args.ollamaApi !== "generate") throw new Error(`Unsupported Ollama API: ${args.ollamaApi}`);
  const prompt = buildPrompt(args);
  const body = {
    model: model.id,
    prompt,
    stream: false,
    keep_alive: args.keepAlive,
    options: {
      temperature: args.temperature,
      top_p: args.topP,
      num_predict: args.maxTokens,
    },
  };
  if (args.contextLength > 0) body.options.num_ctx = args.contextLength;
  if (args.think !== "default") body.think = args.think === "true";
  const started = performance.now();
  const data = await fetchJson(`${provider.baseUrl.replace(/\/$/, "")}/api/generate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }, args.timeoutSeconds);
  const elapsedMs = Math.round(performance.now() - started);
  return {
    provider: provider.name,
    model: model.id,
    status: "completed",
    elapsed_ms: elapsedMs,
    prompt,
    request: body,
    response: data,
    output: data.response ?? "",
    usage: {
      prompt_eval_count: data.prompt_eval_count,
      eval_count: data.eval_count,
      total_duration: data.total_duration,
      load_duration: data.load_duration,
      prompt_eval_duration: data.prompt_eval_duration,
      eval_duration: data.eval_duration,
    },
  };
}

async function runOllamaChat(provider, model, args) {
  const prompt = buildPrompt(args);
  const body = {
    model: model.id,
    messages: [
      {
        role: "system",
        content: "Return only the final answer requested by the user. Do not include hidden reasoning, markdown fences, or explanatory prose.",
      },
      { role: "user", content: prompt },
    ],
    stream: false,
    keep_alive: args.keepAlive,
    options: {
      temperature: args.temperature,
      top_p: args.topP,
      num_predict: args.maxTokens,
    },
  };
  if (args.contextLength > 0) body.options.num_ctx = args.contextLength;
  if (args.think !== "default") body.think = args.think === "true";
  const started = performance.now();
  const data = await fetchJson(`${provider.baseUrl.replace(/\/$/, "")}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }, args.timeoutSeconds);
  const elapsedMs = Math.round(performance.now() - started);
  const message = data.message ?? {};
  return {
    provider: provider.name,
    model: model.id,
    status: "completed",
    elapsed_ms: elapsedMs,
    prompt,
    request: body,
    response: data,
    output: [message.thinking, message.reasoning, message.content].filter(Boolean).join("\n\n"),
    usage: {
      prompt_eval_count: data.prompt_eval_count,
      eval_count: data.eval_count,
      total_duration: data.total_duration,
      load_duration: data.load_duration,
      prompt_eval_duration: data.prompt_eval_duration,
      eval_duration: data.eval_duration,
    },
  };
}

function extractHtml(output) {
  const text = stripReasoningTrace(output);
  const fence = text.match(/```(?:html)?\s*([\s\S]*?)```/i);
  const candidate = fence ? fence[1].trim() : text;
  const doctypeIndex = candidate.toLowerCase().indexOf("<!doctype");
  const htmlIndex = candidate.toLowerCase().indexOf("<html");
  const start = doctypeIndex >= 0 ? doctypeIndex : htmlIndex;
  if (start >= 0) {
    const sliced = candidate.slice(start);
    const end = sliced.toLowerCase().lastIndexOf("</html>");
    return end >= 0 ? sliced.slice(0, end + 7).trim() : sliced.trim();
  }
  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>No HTML extracted</title></head>
<body><pre>${escapeHtml(text)}</pre></body>
</html>`;
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function featureScan(html, output) {
  const lowerHtml = html.toLowerCase();
  const lowerAll = `${html}\n${output}`.toLowerCase();
  const externalScript = /<script[^>]+src\s*=/.test(lowerHtml);
  const externalCss = /<link[^>]+stylesheet|@import\s+url/.test(lowerHtml);
  const features = {
    complete_html: /<html[\s>]/i.test(html) && /<\/html>/i.test(html),
    canvas: /<canvas[\s>]/i.test(html) || /createelement\(['"]canvas/i.test(lowerHtml),
    animation: /requestanimationframe|setinterval|settimeout/.test(lowerHtml),
    rotation: /rotate|rotation|angle|spin|spit/.test(lowerAll),
    vertical_skewer: /skewer|spit|rod|vertical/.test(lowerAll),
    meat_stack: /meat|kebab|doner|döner|shawarma|layer/.test(lowerAll),
    heating_element: /gas|burner|flame|fire|heat|heater|element/.test(lowerAll),
    no_external_libraries: !externalScript && !externalCss && !/https?:\/\//.test(lowerHtml),
  };
  const score = Object.values(features).filter(Boolean).length;
  return { features, code_feature_score: score, max_code_feature_score: Object.keys(features).length };
}

function writeRunArtifacts(runDir, result) {
  const modelDir = path.join(runDir, "runs", `${safeName(result.provider)}__${safeName(result.model)}`);
  fs.mkdirSync(modelDir, { recursive: true });
  const html = extractHtml(result.output);
  const scan = featureScan(html, result.output);
  const enriched = {
    ...result,
    ...scan,
    output_chars: result.output.length,
    html_chars: html.length,
    artifact_dir: path.relative(runDir, modelDir).replace(/\\/g, "/"),
  };
  fs.writeFileSync(path.join(modelDir, "response.json"), JSON.stringify(result.response ?? result.error ?? {}, null, 2), "utf8");
  fs.writeFileSync(path.join(modelDir, "output.raw.txt"), result.output ?? "", "utf8");
  fs.writeFileSync(path.join(modelDir, "output.html"), html, "utf8");
  fs.writeFileSync(path.join(modelDir, "run.json"), JSON.stringify(enriched, null, 2), "utf8");
  return enriched;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const providersByName = { ...DEFAULT_PROVIDERS };
  if (args.openaiProvider || args.openaiBaseUrl || args.openaiModelsUrl) {
    if (!args.openaiProvider || !args.openaiBaseUrl) {
      throw new Error("--openai-provider and --openai-base-url must be provided together");
    }
    const baseUrl = args.openaiBaseUrl.replace(/\/$/, "");
    providersByName[args.openaiProvider] = {
      name: args.openaiProvider,
      kind: "openai",
      baseUrl,
      modelsUrl: args.openaiModelsUrl || `${baseUrl}/models`,
    };
  }
  const providerNames = args.providers.split(",").map((name) => name.trim()).filter(Boolean);
  const providers = providerNames.map((name) => {
    const provider = providersByName[name];
    if (!provider) throw new Error(`Unknown provider: ${name}`);
    return provider;
  });
  const runDir = path.join(resultsRoot, args.runId);
  fs.mkdirSync(runDir, { recursive: true });
  const inventory = {};
  const summary = {
    run_id: args.runId,
    created_at: new Date().toISOString(),
    prompt: buildPrompt(args),
    args,
    providers: {},
    results: [],
  };

  for (const provider of providers) {
    process.stdout.write(`\n[${provider.name}] discovering models from ${provider.modelsUrl}\n`);
    try {
      const models = selectModels(await listModels(provider), args.models);
      inventory[provider.name] = models;
      summary.providers[provider.name] = { status: "reachable", model_count: models.length, models: models.map((model) => model.id) };
      for (const model of models) {
        process.stdout.write(`[${provider.name}] running ${model.id}\n`);
        try {
          const result = provider.kind === "openai"
            ? await runOpenAI(provider, model, args)
            : await runOllama(provider, model, args);
          const enriched = writeRunArtifacts(runDir, result);
          summary.results.push(enriched);
          process.stdout.write(`[${provider.name}] completed ${model.id} in ${Math.round(enriched.elapsed_ms / 1000)}s, code score ${enriched.code_feature_score}/${enriched.max_code_feature_score}\n`);
        } catch (error) {
          const failed = {
            provider: provider.name,
            model: model.id,
            status: "failed",
            elapsed_ms: null,
            prompt: buildPrompt(args),
            request: {
              provider_kind: provider.kind,
              ollama_api: provider.kind === "ollama" ? args.ollamaApi : null,
            },
            output: "",
            error: {
              message: error.message,
              data: error.data ?? null,
              stack: error.stack,
            },
          };
          const enriched = writeRunArtifacts(runDir, failed);
          summary.results.push(enriched);
          process.stdout.write(`[${provider.name}] failed ${model.id}: ${error.message}\n`);
        }
      }
    } catch (error) {
      summary.providers[provider.name] = { status: "failed", error: error.message };
      process.stdout.write(`[${provider.name}] provider failed: ${error.message}\n`);
    }
  }

  fs.writeFileSync(path.join(runDir, "inventory.json"), JSON.stringify(inventory, null, 2), "utf8");
  fs.writeFileSync(path.join(runDir, "summary.json"), JSON.stringify(summary, null, 2), "utf8");
  process.stdout.write(`\nWrote ${path.relative(process.cwd(), runDir)}\n`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
