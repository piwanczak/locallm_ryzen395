# Kebab Benchmark Full Local Run Rollup

## Result

Run `20260625-1938-full` executed the informal Kebab Benchmark prompt across all discovered local LLMs exposed by LM Studio, Windows Ollama, and WSL Ollama.

- Total model/provider rows: 21
- Completed generations: 12
- Transport failures: 9
- Best visual result: Windows Ollama `qwen3-coder:30b`
- Best speed/quality tradeoff among usable results: LM Studio `qwen/qwen3-coder-30b`
- Contact sheet: [contact-sheet.png](../../../public-results/results-summary.md)

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

## Scoring

Manual visual score is 0-5:

- 0: failed, blank, or unusable render.
- 1: tiny/minimal geometry that does not satisfy the scene.
- 2: partial scene with serious geometry or placement failures.
- 3: recognizable skewer/heater scene with major realism issues.
- 4: clear working simulation but cartoon/schematic rather than realistic.
- 5: strong realistic vertical Döner skewer, heater, and convincing rotation.

The automatic code feature score is kept only as a smoke check. Several outputs scored 8/8 in code features while rendering blank or nearly blank.

## Provider Summary

| Provider | Completed | Failed | Notes |
| --- | ---: | ---: | --- |
| LM Studio | 7 | 2 | Good API coverage; DeepSeek 8B and Kimi 72B failed with `fetch failed`. |
| Ollama Windows | 3 | 3 | Qwen 30B produced the best visual; R1 and Kimi 72B failed with `fetch failed`. |
| Ollama WSL | 2 | 4 | Qwen 30B completed faster than Windows but the visual was less faithful; multiple large/reasoning models failed. |

## Ranking

| Rank | Provider | Model | Time | Visual | Screenshot | Notes |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | Ollama Windows | `qwen3-coder:30b` | 289s | 4/5 | [png](../../../public-results/results-summary.md) | Clear vertical skewer, colored meat stack, burner/flame, speed control, and animation hooks. Cartoon-like, not realistic. |
| 2 | LM Studio | `qwen/qwen3-coder-30b` | 91s | 3/5 | [png](../../../public-results/results-summary.md) | Has skewer, glow, flame, and animation hooks, but the meat looks like a sphere/odd object rather than a layered kebab. |
| 3 | Ollama WSL | `qwen3-coder:30b` | 152s | 3/5 | [png](../../../public-results/results-summary.md) | Recognizable meat/heater elements and animation hooks, but reads more like a top-down meat cluster than a vertical rotisserie in front of a heater. |
| 4 | LM Studio | `google/gemma-4-e4b` | 71s | 1/5 | [png](../../../public-results/results-summary.md) | Animated-looking fragments and red heat band, but no coherent vertical skewer or kebab stack. |
| 5 | Ollama Windows | `gemma3:12b` | 171s | 1/5 | [png](../../../public-results/results-summary.md) | Rendered mostly off-screen; only a small shape appears at the top. |
| 6 | LM Studio | `qwen2.5-coder-1.5b-instruct@q4_k_m` | 6s | 1/5 | [png](../../../public-results/results-summary.md) | Minimal yellow triangle and black line; not a kebab/heater scene. |

All other completed rows had blank, near-blank, invalid, or unusable renders and score 0/5.

## Full Table

| Provider | Model | Status | Time | Code | Visual | Artifacts | Visual note |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| LM Studio | `qwen3-0.6b` | completed | 20s | 7/8 | 0/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Mostly blank canvas with faint circle. |
| LM Studio | `qwen2.5-coder-1.5b-instruct@q4_k_m` | completed | 6s | 8/8 | 1/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Minimal geometry only. |
| LM Studio | `qwen2.5-coder-1.5b-instruct@q8_0` | completed | 8s | 6/8 | 0/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Blank/white render. |
| LM Studio | `google/gemma-4-e4b` | completed | 71s | 8/8 | 1/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Fragmented shapes, weak scene. |
| LM Studio | `deepseek-r1-0528-qwen3-8b` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| LM Studio | `google/gemma-4-12b` | completed | 245s | 8/8 | 0/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Dark/blank render despite high code score. |
| LM Studio | `qwen/qwen3-coder-30b` | completed | 91s | 8/8 | 3/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Usable but not realistic. |
| LM Studio | `unsloth/qwen3-coder-30b-a3b-instruct` | completed | 47s | 8/8 | 0/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Solid dark render. |
| LM Studio | `kimi-dev-72b` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| Ollama Windows | `gemma3n:e4b` | completed | 70s | 7/8 | 0/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Blank/invalid render; raw code contained `▁` markers. |
| Ollama Windows | `deepseek-r1:8b` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| Ollama Windows | `gemma3:12b` | completed | 171s | 8/8 | 1/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Mostly off-screen. |
| Ollama Windows | `qwen3-coder:30b` | completed | 289s | 8/8 | 4/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Best overall local result. |
| Ollama Windows | `deepseek-r1:32b` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| Ollama Windows | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| Ollama WSL | `gemma3n:e4b` | completed | 107s | 8/8 | 0/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Blank/invalid render with visible marker artifacts. |
| Ollama WSL | `deepseek-r1:8b` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| Ollama WSL | `gemma3:12b` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| Ollama WSL | `qwen3-coder:30b` | completed | 152s | 8/8 | 3/5 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) | Usable but less faithful than Windows Qwen. |
| Ollama WSL | `deepseek-r1:32b` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |
| Ollama WSL | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | failed | 0s | 2/8 | 0/5 | [png](../../../public-results/results-summary.md) | `fetch failed`. |

## Conclusions

The Kebab Benchmark is useful as a quick visual smoke test, but the run reinforces its limits: one prompt and one sample are not statistically meaningful. It is still good at exposing practical local-model failures that text-only code checks miss:

- Code-feature scoring overestimated many outputs.
- Several models produced syntactically plausible HTML that rendered blank.
- Gemma3n via Ollama emitted visible SentencePiece-style `▁` markers that broke JavaScript/CSS formatting.
- Larger/reasoning models often failed at the transport layer before producing usable artifacts.
- Qwen 30B was the only family to produce consistently recognizable Kebab Benchmark scenes across multiple providers.

## Sources

- Reddit: https://www.reddit.com/r/LocalLLaMA/comments/1ua1na0/whats_more_impressive_glm_51_52_or_qwen_35_36/
- EvaluateAI comparison: https://evaluateai.ai/app/comparisons/0e156620-928b-4a40-bded-84ed556309c5/results/?view=model
- LinkedIn discussion: https://www.linkedin.com/posts/kirtspaulding_public-llm-benchmarks-are-useful-but-they-activity-7473884548670332929-SX3t
