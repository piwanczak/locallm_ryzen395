# OpenCode Agent Benchmark

Disposable benchmark workspace for comparing local LM Studio models under OpenCode.

Key safety choices:

- OpenCode is run with `--dir` pointing at copied fixture workspaces under `fixtures/work`.
- XDG config/data/cache/state and temp paths are redirected into this benchmark directory.
- The benchmark config denies `external_directory`, `websearch`, user questions, destructive shell patterns, and package installs.
- The LM Studio timing proxy only forwards to `http://127.0.0.1:1234`.
- Each run is graded from fixture-local files and a before/after manifest.

Run order:

```powershell
node scripts/setup-benchmark.mjs
.\scripts\reset-fixtures.ps1
.\scripts\run-opencode-benchmark.ps1 -Profile gemma-65k -Tasks python-ledger
```
