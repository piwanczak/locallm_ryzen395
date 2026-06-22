# Sandbox Boundary

This benchmark uses an application-level disposable sandbox, not a kernel or VM boundary.

Boundary controls:

- Fixture working directories are copied from `templates/` into `fixtures/work/<run-id>/`.
- OpenCode receives `--dir <fixture-workdir>` for each task.
- `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`, `TEMP`, and `TMP` point under this benchmark root.
- OpenCode config sets `permission.external_directory = deny`.
- OpenCode config denies `websearch`, package installs, git commit/push, and common destructive shell commands.
- The local web retrieval fixture serves static files from the fixture only.
- The timing proxy forwards only to local LM Studio at `127.0.0.1:1234`.

Verification:

- The runner records resolved OpenCode paths before runs.
- Each run records a manifest of files before and after the agent.
- The grader reports files modified outside the task workspace, if any.
- A canary file is placed under `fixtures/canary/outside-fixture-canary.txt`; it must remain unchanged.

Residual risk:

OpenCode permissions are not an operating-system sandbox. The benchmark therefore avoids real project repos, personal browser sessions, real credentials, and live websites, and treats all model-driven runs as disposable.
