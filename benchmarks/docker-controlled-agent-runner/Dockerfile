FROM node:24-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ENTRYPOINT ["node", "/workspace/benchmarks/wsl-local-inference-benchmark/scripts/run-controlled-edit-agent.mjs"]
