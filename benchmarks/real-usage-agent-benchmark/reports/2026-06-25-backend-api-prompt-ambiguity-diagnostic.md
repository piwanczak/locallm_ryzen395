# Backend API Prompt Ambiguity Diagnostic

Date: 2026-06-25

## Bottom Line

The `backend-api` failure should be classified primarily as benchmark prompt
ambiguity, not as a clean Qwen3-Coder-Next Q4 model-quality failure.

Both tested models failed the canonical task prompt and passed once the
verifier's implicit contract was made explicit:

- Qwen3-Coder-Next Q4 `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M`: fail
  canonical, pass full-contract clarification on attempt 1.
- Current promoted agentic baseline `qwen3-coder:30b` / Qwen3 Coder 30B Q4:
  fail canonical, pass full-contract clarification on attempt 1.

Recommendation: keep the promoted local stack unchanged, but do not use the
current canonical `backend-api` task as a promotion or demotion gate until its
task prompt/fixture README is revised. The task should explicitly specify the
discount/tax rounding contract and either document the accepted 400-error
message keywords or relax the verifier to check status/structure instead of
lexical wording.

## What Is Ambiguous

Canonical task definition:

- [tasks.json](../tasks.json) asks the model to compute `subtotalCents`,
  `discountCents`, `taxCents`, `totalCents`, and `lineCount`.
- [README.md](../fixtures/templates/backend-api/README.md) says to calculate
  cent-based subtotal, discount, tax, total, and line count.
- [tools/test.mjs](../fixtures/templates/backend-api/tools/test.mjs) asserts
  exact `taxableCents`, tax, total, and error-message regexes.

The missing domain rule is how the order-level discount affects taxable base.
The verifier expects:

```text
subtotalCents = 1299*2 + 450*3 + 2500 = 6448
taxableBeforeDiscountCents = 1299*2 + 450*3 = 3948
discountCents = Math.round(6448 * 10 / 100) = 645
taxableCents = Math.round(3948 * (6448 - 645) / 6448) = 3553
taxCents = Math.round(3553 * 725 / 10000) = 258
totalCents = 6448 - 645 + 258 = 6061
```

That proportional taxable-base rule is present only by implication in the test
expected values and reference solution. A common implementation instead taxes
the pre-discount taxable subtotal, producing `taxableCents=3948` and
`taxCents=286`.

The verifier also requires each invalid-input `body.error` to match
`/invalid|unknown|required|positive|items/i`. The README only says to return
400 JSON errors for invalid input. Qwen3-Coder-Next Q4 produced
`unsupported region` under the tax-rule-only clarification; that is semantically
reasonable but fails the regex.

## Controlled Runs

All rows used the direct OpenAI-compatible JSON-edit harness against Windows
Ollama at `http://127.0.0.1:11434/v1`, requested `16384` context, and edited
only `src/orders.mjs`. The canary stayed unchanged in every row and there were
no allowlist or protected-text violations.

| Model | Prompt variant | Result | Attempts | Key reading | Evidence |
| --- | --- | --- | ---: | --- | --- |
| Qwen3-Coder-Next Q4 | canonical | fail | 2 | Attempt 1 had `body is not defined`; attempt 2 fixed that but returned `taxableCents=3948`, `taxCents=286`, `totalCents=6089` instead of `3553`, `258`, `6061`. | [summary](../../../public-results/results-summary.md) |
| Qwen3-Coder-Next Q4 | tax-rule clarification | fail | 2 | Math was corrected, but `unsupported region` failed the verifier's error-message regex. | [summary](../../../public-results/results-summary.md), [prompt fragment](../../../public-results/results-summary.md) |
| Qwen3-Coder-Next Q4 | full verifier contract | pass | 1 | Passed once taxable-base rounding and error-message keyword requirements were explicit. | [summary](../../../public-results/results-summary.md), [prompt fragment](../../../public-results/results-summary.md) |
| Qwen3 Coder 30B Q4 | canonical | fail | 2 | Returned `discountCents=644`, `taxableCents=3948`, `taxCents=286`, `totalCents=6090`; repair attempt repeated the same logic. | [summary](../../../public-results/results-summary.md) |
| Qwen3 Coder 30B Q4 | full verifier contract | pass | 1 | Passed once the same verifier contract was explicit. | [summary](../../../public-results/results-summary.md), [prompt fragment](../../../public-results/results-summary.md) |

## Interpretation

The canonical task is still useful as a stress test for inferring behavior from
tests, but it is not a fair standalone backend feature specification. It asks
for money arithmetic while leaving two scoring-critical details implicit:

- whether tier discounts reduce the taxable base before tax;
- what wording invalid-input errors must include.

The strongest evidence is not that Qwen3-Coder-Next Q4 suddenly became better;
it is that both Qwen3-Coder-Next Q4 and the promoted Qwen3 Coder 30B Q4 baseline
cross from fail to pass under the same full-contract clarification. That pattern
points to task specification ambiguity rather than a model-specific backend
quality defect.

The Qwen3-Coder-Next Q4 result should still not promote the model. The Q4 row
is much slower on this hardware and the pass was obtained only after turning
implicit verifier behavior into explicit prompt text. The correct update is to
fix the benchmark task contract, then rerun model comparisons.

## Harness Change

The direct API harness now accepts optional prompt additions:

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\real-usage-suite.mjs run-api `
  --task backend-api `
  --prompt-extra-file .\benchmarks\real-usage-agent-benchmark\prompts\backend-api-full-verifier-contract-clarification.md
```

Canonical behavior is unchanged when no prompt-extra option is passed. A
backend-only self-test passed after the harness change:

- [self-test summary](../../../public-results/results-summary.md)

## Recommended Benchmark Fix

Revise `backend-api` before using it as a model-quality gate:

- Add the exact taxable-base formula and rounding rules to the task prompt or
  fixture README.
- Either add `taxableCents` to the task prompt's list of required output fields
  or remove it from the verifier's success-body assertion.
- Replace the error-message regex with structural checks where possible, or
  document the accepted error keywords in the task prompt.
- After the task text changes, rerun at least Qwen3-Coder-Next Q4 and
  `qwen3-coder:30b` on the revised canonical prompt.
