#!/usr/bin/env bash
set -euo pipefail

if [[ "${CONFIRM_WSL_ROCDXG_INSTALL:-0}" != "1" ]]; then
  echo "Refusing to install ROCm/ROCDXG without CONFIRM_WSL_ROCDXG_INSTALL=1" >&2
  exit 2
fi

if [[ ! -e /dev/dxg ]]; then
  echo "Missing /dev/dxg; ROCDXG cannot work until WSL GPU virtualization is visible." >&2
  exit 3
fi

export DEBIAN_FRONTEND=noninteractive

rocm_version="${ROCM_VERSION:-7.2.4}"
amdgpu_install_version="${AMDGPU_INSTALL_VERSION:-7.2.4.70204-1}"
amdgpu_deb="amdgpu-install_${amdgpu_install_version}_all.deb"
amdgpu_url="https://repo.radeon.com/amdgpu-install/${rocm_version}/ubuntu/noble/${amdgpu_deb}"

rocdxg_version="${ROCDXG_VERSION:-1.2.0}"
rocdxg_deb="rocdxg-roct_${rocdxg_version}_amd64.deb"
rocdxg_url="https://github.com/ROCm/librocdxg/releases/download/v${rocdxg_version}/${rocdxg_deb}"
rocdxg_sha256="${ROCDXG_SHA256:-3ed9526719290cd8f590150dad8ea0f234fa779bea6a4c9a8449d7ae6b8cfb6e}"

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  python3-setuptools \
  python3-wheel \
  wget

workdir="${ROCDXG_WORKDIR:-/opt/rocm-setup}"
mkdir -p "$workdir"
cd "$workdir"

if [[ ! -f "$amdgpu_deb" ]]; then
  wget -O "$amdgpu_deb" "$amdgpu_url"
fi

apt-get install -y "./$amdgpu_deb"
apt-get update

if [[ ! -f "$rocdxg_deb" ]]; then
  wget -O "$rocdxg_deb" "$rocdxg_url"
fi

printf '%s  %s\n' "$rocdxg_sha256" "$rocdxg_deb" | sha256sum -c -

# Do not install amdgpu-dkms on WSL. ROCDXG routes ROCm userspace through /dev/dxg.
apt-get install -y rocm "./$rocdxg_deb"

cat >/etc/profile.d/rocdxg.sh <<'EOF'
export HSA_ENABLE_DXG_DETECTION=1
EOF

echo "ROCm $rocm_version and ROCDXG $rocdxg_version installed"
