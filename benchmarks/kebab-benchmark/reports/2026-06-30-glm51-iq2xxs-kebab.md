# Kebab Benchmark Run 20260630-glm51-iq2xxs-kebab

## Summary

- Prompt source: LocalLLaMA/EvaluateAI informal Kebab Benchmark.
- Local run directory: `../results/20260630-glm51-iq2xxs-kebab`
- Completed runs: 0
- Failed runs: 1
- Generated at: 2026-06-30T01:42:10.626Z

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

## Provider Inventory

- llama-vulkan: 1 models: glm-5.1-iq2-xxs

## Results

Code feature score is an automatic smoke score over the emitted HTML/text. It is not a substitute for inspecting the rendered screenshot.

| Provider | Model | Status | Time | Code features | Artifacts | Visual score notes |
| --- | --- | --- | ---: | ---: | --- | --- |
| llama-vulkan | glm-5.1-iq2-xxs | failed |  | 2/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | |

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
