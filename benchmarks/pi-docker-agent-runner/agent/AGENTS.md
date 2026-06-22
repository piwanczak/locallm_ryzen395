# Pi Container Guardrails

Operate only inside `/workspace` unless the user explicitly asks otherwise.

Use the local OpenAI-compatible provider configured in `~/.pi/agent/models.json` first. Do not add package installs, network research, browser automation, or long-running benchmarks unless the current task explicitly needs them.

For coding tasks, prefer small edits, run the narrowest relevant checks, and report exact files changed. Do not run destructive git commands, create commits, push branches, or modify host-level configuration from inside this container.

For frontend tasks, use the browser-capable image only when browser verification is part of the task. Keep generated artifacts and test output inside `/workspace`.
