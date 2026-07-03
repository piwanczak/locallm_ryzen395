# Kebab Benchmark Run 20260627-ornith-9b-q4km-kebab-generate-framed-8192

## Summary

- Prompt source: LocalLLaMA/EvaluateAI informal Kebab Benchmark.
- Local run directory: `../results/20260627-ornith-9b-q4km-kebab-generate-framed-8192`
- Completed runs: 1
- Failed runs: 0
- Generated at: 2026-06-27T08:08:58.270Z

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.

Return only one complete HTML document. Do not include markdown fences, prose, or reasoning. Keep the entire vertical kebab skewer, meat stack, and gas burner fully inside the initial 1280x768 viewport, centered with minimal empty space.
```

## Provider Inventory

- ollama-windows: 1 models: hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M

## Results

Code feature score is an automatic smoke score over the emitted HTML/text. It is not a substitute for inspecting the rendered screenshot.

| Provider | Model | Status | Time | Code features | Artifacts | Visual score notes |
| --- | --- | --- | ---: | ---: | --- | --- |
| ollama-windows | hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M | completed | 245.0s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | Manual visual score: 3/5. Complete animated canvas with centered meat stack and burner, but the skewer geometry is cartoonish and not convincingly realistic. |

## Tuning Notes

- Best Kebab setting found: Ollama `/api/generate`, 16k context, 8192 output ceiling, `temperature=0.2`, `top_p=0.9`, and explicit final-answer/framing guidance.
- Native `/api/chat` with `think=false` suppressed reasoning text, but the 4096-token run rendered blank after truncation and the 8192-token run failed transport-side with `fetch failed`.
- `/api/generate` still emitted a leading `<think>` block even with `think=false`; the benchmark extractor now strips it before HTML extraction.

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
