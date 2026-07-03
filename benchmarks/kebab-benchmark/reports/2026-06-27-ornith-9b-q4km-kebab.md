# Kebab Benchmark Run 20260627-ornith-9b-q4km-kebab-2048

## Summary

- Prompt source: LocalLLaMA/EvaluateAI informal Kebab Benchmark.
- Local run directory: `../results/20260627-ornith-9b-q4km-kebab-2048`
- Completed runs: 1
- Failed runs: 0
- Generated at: 2026-06-27T05:48:05.035Z

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

## Provider Inventory

- ollama-windows: 1 models: hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M

## Results

Code feature score is an automatic smoke score over the emitted HTML/text. It is not a substitute for inspecting the rendered screenshot.

| Provider | Model | Status | Time | Code features | Artifacts | Visual score notes |
| --- | --- | --- | ---: | ---: | --- | --- |
| ollama-windows | hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M | completed | 108.9s | 6/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | Manual visual score `0/5`: rendered page shows the model's `<think>` planning text rather than a canvas kebab scene. |

## Ornith-Specific Note

The first Kebab attempt used the standard `8192` token cap and failed after model selection with `fetch failed`. A short direct Ollama generate smoke then succeeded, so the promoted Kebab evidence is the retry with `max_tokens=2048`, `temperature=0.2`, and `top_p=0.9`.

The model card describes Ornith-1.0-9B as a reasoning model whose assistant turn opens with a `<think>...</think>` block unless the serving stack separates reasoning into a dedicated field. The current Ollama/Kebab path did not separate that reasoning block, so the extracted HTML artifact rendered the reasoning text as page content instead of a usable generated app.

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
