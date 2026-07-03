# Kebab Benchmark Run 20260625-212346-qwen3-coder-next-ollama-ud-q2-xl-kebab

## Summary

- Prompt source: LocalLLaMA/EvaluateAI informal Kebab Benchmark.
- Local run directory: `../results/20260625-212346-qwen3-coder-next-ollama-ud-q2-xl-kebab`
- Completed runs: 1
- Failed runs: 0
- Generated at: 2026-06-25T19:27:06.887Z

## Prompt

```text
Write a single HTML file with a full-page canvas and no libraries. Simulate a realistic Döner Style kebab skewer rotating (vertically) in front of a gas powered heating element.
```

## Provider Inventory

- ollama-windows: 1 models: hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL

## Results

Code feature score is an automatic smoke score over the emitted HTML/text. It is not a substitute for inspecting the rendered screenshot.

| Provider | Model | Status | Time | Code features | Artifacts | Visual score notes |
| --- | --- | --- | ---: | ---: | --- | --- |
| ollama-windows | hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL | completed | 168.2s | 8/8 | [png](../../../public-results/results-summary.md) [html](../../../public-results/results-summary.md) [raw](../../../public-results/results-summary.md) | Complete single-file canvas with animation and heat elements, but the rendered result is stylized and geometric rather than a realistic doner setup. |

## Manual Visual Inspection

The generated page satisfies the structural prompt: a single HTML file, full-page
canvas, animated vertical skewer, heating/flame elements, and no external
libraries. The automatic code feature score is therefore `8/8`.

The screenshot is only a moderate visual hit. It shows a dark scene with a
horizontal heat/flame band, a central rotating colored conical skewer, and title
text. The skewer reads more like a colorful geometric cone than layered roasted
meat, and the heater is more of an abstract glow strip than a plausible gas
burner behind the meat. Use this as evidence that the model can satisfy the
canvas/programming constraints, not as evidence of strong visual realism.

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
