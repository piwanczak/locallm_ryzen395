# Kebab Benchmark Research and Harness Setup

## Milestone

The Kebab Benchmark was identified as an informal LocalLLaMA/EvaluateAI visual code-generation comparison, not an official benchmark package. A local harness now exists under `benchmarks/kebab-benchmark/` to run the prompt against LM Studio, Windows Ollama, and WSL Ollama, preserve raw outputs, extract generated HTML, render screenshots with headless Chrome, and produce Markdown/HTML reports.

## Source

Exact prompt:

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

Primary sources:

- Reddit post: https://www.reddit.com/r/LocalLLaMA/comments/1ua1na0/whats_more_impressive_glm_51_52_or_qwen_35_36/
- EvaluateAI comparison data: https://evaluateai.ai/app/comparisons/0e156620-928b-4a40-bded-84ed556309c5/results/?view=model
- LinkedIn discussion pointing to the comparison: https://www.linkedin.com/posts/kirtspaulding_public-llm-benchmarks-are-useful-but-they-activity-7473884548670332929-SX3t

## Method

The benchmark is judged visually after generated code runs. The local reproduction uses these checks:

- Preserve each raw response exactly.
- Extract the first HTML block to `output.html`.
- Render `output.html` in Chrome headless after a short virtual-time budget.
- Keep `screenshot.png`, `run.json`, `response.json`, and `output.raw.txt` under ignored `results/`.
- Compute a smoke-only code feature score for HTML completeness, canvas usage, animation, rotation terms, skewer/meat/heater terms, and no obvious external libraries.

The code feature score is only a guardrail. The actual benchmark needs visual inspection because a model can mention every required concept in code comments while rendering nothing useful.

## Local Endpoints

| Surface | Endpoint | Status | Models found |
| --- | --- | --- | ---: |
| LM Studio | `http://127.0.0.1:1234/v1` | reachable | 9 LLMs |
| Ollama Windows | `http://127.0.0.1:11434` | reachable | 6 LLMs |
| Ollama WSL | `http://127.0.0.1:11435` | reachable | 6 LLMs |

WSL Ollama is running on port `11435`; the default WSL CLI target `11434` does not connect unless `OLLAMA_HOST=http://127.0.0.1:11435` is supplied.

## Smoke Results

| Run | Provider/model | Result |
| --- | --- | --- |
| `20260625-1927-smoke-lmstudio` | LM Studio `qwen3-0.6b` | API, extraction, and screenshot path worked; visual result was effectively a blank radial canvas. |
| `20260625-1928-smoke-ollama` | Windows and WSL `gemma3n:e4b` | APIs and screenshot path worked; generated code contained SentencePiece-style `▁` markers, causing rendered pages to be blank/invalid. |

These smoke failures are retained as benchmark evidence rather than cleaned up: they show why raw-output preservation and screenshot rendering matter.

## Next Step

Run the full provider matrix with the exact prompt, then create a run rollup with artifact links and manual visual notes.
