#!/usr/bin/env bash
set -euo pipefail

if [[ "${CONFIRM_WSL_BASE_TOOLS_INSTALL:-0}" != "1" ]]; then
  echo "Refusing to install packages without CONFIRM_WSL_BASE_TOOLS_INSTALL=1" >&2
  exit 2
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  clinfo \
  cmake \
  curl \
  g++ \
  gcc \
  git \
  jq \
  make \
  mesa-vulkan-drivers \
  ninja-build \
  pkg-config \
  python3-pip \
  python3-setuptools \
  python3-venv \
  python3-wheel \
  unzip \
  vulkan-tools \
  wget

echo "base tools installed"
