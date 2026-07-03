# Kebab Benchmark Run 20260629-qwen36-q4km

## Summary

- Prompt source: LocalLLaMA/EvaluateAI informal Kebab Benchmark.
- Local run directory: `../results/20260629-qwen36-q4km`
- Completed runs: 1
- Failed runs: 0
- Generated at: 2026-06-29T20:04:19.666Z
- Manual visual score: `0/5`.

Qwen3.6 generated a long single-file canvas program with an automatic code
feature score of `8/8`, but the rendered screenshot was effectively a uniform
dark canvas. Treat this as a visual failure. Static inspection points to a
generated JavaScript bug in texture setup, where `createPattern` is called on a
canvas element instead of a 2D context, so the animation does not reach the
drawn kebab scene.

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
| 1 | ollama-windows | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | 146.0s | 0/5 | Screenshot is essentially uniform dark background; generated code likely throws before drawing. |

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

## Provider Inventory

- ollama-windows: 1 models: hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M

## Results

Code feature score is an automatic smoke score over the emitted HTML/text. It is not a substitute for inspecting the rendered screenshot.

| Provider | Model | Status | Time | Code features | Artifacts | Visual score notes |
| --- | --- | --- | ---: | ---: | --- | --- |
| ollama-windows | hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M | completed | 146.0s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | Manual `0/5`; rendered canvas is blank/dark despite code-feature match. |

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
