# Kebab Benchmark Run 20260626-2300-bios307-full

## Summary

- Prompt source: LocalLLaMA/EvaluateAI informal Kebab Benchmark.
- Local run directory: `../results/20260626-2300-bios307-full`
- Completed runs: 11
- Failed runs: 7
- Generated at: 2026-06-26T22:09:15.294Z
- Contact sheet: [contact-sheet.png](../../../public-results/results-summary.md)

## Manual Visual Ranking

Manual visual score is 0-5:

- 0: failed, blank, text-only, or unusable render.
- 1: tiny/minimal geometry that does not satisfy the full scene.
- 2: partial recognizable scene with serious geometry or realism failures.
- 3: recognizable skewer/heater scene, but schematic or missing a realistic layered meat stack.
- 4: clear working simulation, still cartoon/schematic.
- 5: strong realistic vertical doner skewer, heater, and convincing rotation.

| Rank | Provider | Model | Time | Visual | Notes |
| ---: | --- | --- | ---: | ---: | --- |
| 1 | ollama-windows | `qwen3-coder:30b` | 247.3s | 3/5 | Best visual in this run: recognizable skewer/flame scene with controls, but meat is a simplified ring and not a layered doner stack. |
| 2 | lmstudio | `google/gemma-4-12b` | 188.4s | 2/5 | Nonblank meat/flame composition; abstract geometry and no convincing vertical rotisserie. |
| 3 | lmstudio | `qwen/qwen3-coder-30b` | 91.9s | 2/5 | Small labeled scene with skewer/flame elements; tiny and schematic. |
| 4 | lmstudio | `unsloth/qwen3-coder-30b-a3b-instruct` | 53.2s | 2/5 | Vertical rod and colored objects; weak kebab/heater semantics. |
| 5 | lmstudio | `google/gemma-4-e4b` | 96.9s | 1/5 | Small flame and fragments only. |
| 6 | ollama-windows | `gemma3:12b` | 171.3s | 1/5 | Vertical rod and base only; no convincing meat stack or heater. |

All other rows score 0/5. The automatic code feature score overestimated many
outputs: several rows scored 7/8 or 8/8 while rendering blank, text-only, or
minimal geometry.

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

## Provider Inventory

- lmstudio: 10 models: qwen/qwen3-coder-next, kimi-dev-72b, deepseek-r1-0528-qwen3-8b, google/gemma-4-12b, unsloth/qwen3-coder-30b-a3b-instruct, qwen3-0.6b, qwen2.5-coder-1.5b-instruct@q4_k_m, qwen2.5-coder-1.5b-instruct@q8_0, qwen/qwen3-coder-30b, google/gemma-4-e4b
- ollama-windows: 8 models: hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M, hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL, hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS, deepseek-r1:32b, deepseek-r1:8b, gemma3:12b, gemma3n:e4b, qwen3-coder:30b
- ollama-wsl: failed (fetch failed)

## Results

Code feature score is an automatic smoke score over the emitted HTML/text. It is not a substitute for inspecting the rendered screenshot.

| Provider | Model | Status | Time | Code features | Artifacts | Visual score notes |
| --- | --- | --- | ---: | ---: | --- | --- |
| lmstudio | qwen/qwen3-coder-next | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | kimi-dev-72b | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | deepseek-r1-0528-qwen3-8b | completed | 300.0s | 7/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | google/gemma-4-12b | completed | 188.4s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | unsloth/qwen3-coder-30b-a3b-instruct | completed | 53.2s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | qwen3-0.6b | completed | 12.1s | 7/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | qwen2.5-coder-1.5b-instruct@q4_k_m | completed | 7.9s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | qwen2.5-coder-1.5b-instruct@q8_0 | completed | 11.6s | 7/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | qwen/qwen3-coder-30b | completed | 91.9s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| lmstudio | google/gemma-4-e4b | completed | 96.9s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | deepseek-r1:32b | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | deepseek-r1:8b | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | gemma3:12b | completed | 171.3s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | gemma3n:e4b | completed | 65.5s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |
| ollama-windows | qwen3-coder:30b | completed | 247.3s | 6/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |

## Research Notes

The benchmark is informal. The upstream Reddit post uses one prompt and presents generated visual outputs; comments call out concrete failure modes such as missing fire, non-rotation, flat 2D skewers, implausible geometry, and outputs that look better in a static image than in animation. For this local reproduction, a useful manual visual score should consider:

- Single-file HTML and full-page canvas with no external libraries.
- A vertical skewer/spit with a layered meat stack.
- A gas-powered heating element or flame/burner near the meat.
- Visible rotation or animation when rendered.
- Plausible relative placement, lighting, and physical composition.

Sources:

- Reddit: https://www.reddit.com/r/LocalLLaMA/comments/1ua1na0/whats_more_impressive_glm_51_52_or_qwen_35_36/
- EvaluateAI data: https://evaluateai.ai/app/comparisons/0e156620-928b-4a40-bded-84ed556309c5/results/?view=model
- LinkedIn discussion: https://www.linkedin.com/posts/kirtspaulding_public-llm-benchmarks-are-useful-but-they-activity-7473884548670332929-SX3t
