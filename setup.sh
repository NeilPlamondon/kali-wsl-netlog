#!/usr/bin/env bash
# Setup script for kali-wsl-netlab
# Installs deps and enables non-root packet capture.
# Detects WSL to tailor messages and checks.

set -euo pipefail

is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }
need_root() { [[ $EUID -eq 0 ]] || { echo "Run with: sudo $0"; exit 1; }; }
need_root

export DEBIAN_FRONTEND=noninteractive

echo "[1/5] Detecting environment…"
if is_wsl; then
  ENV_NAME="WSL (Windows Subsystem for Linux)"
else
  ENV_NAME="Linux VM/Host"
fi
echo "     -> $ENV_NAME"

echo "[2/5] Updating package lists…"
apt-get update -y

echo "[3/5] Installing tools…"
# tshark/wireshark: packet capture; nmap/netdiscover/arp-scan: discovery; unzip: for releases
apt-get install -y \
  tshark \
  wireshark \
  nmap \
  netdiscover \
  arp-scan \
  unzip

echo "[4/5] Enabling non-root packet capture…"
# Add the invoking user (not root) to wireshark group
TARGET_USER="${SUDO_USER:-$USER}"
usermod -aG wireshark "$TARGET_USER" || true

# On some minimal installs dumpcap may not have caps set; try to fix quietly.
if command -v dumpcap >/dev/null 2>&1; then
  # Only attempt if setcap exists
  if command -v setcap >/dev/null 2>&1; then
    setcap cap_net_raw,cap_net_admin=eip "$(command -v dumpcap)" 2>/dev/null || true
  fi
fi

echo "[5/5] Preparing output folders…"
mkdir -p captures scans

echo
echo "✅ Setup complete for: $ENV_NAME"
echo "   • Installed: tshark/wireshark, nmap, netdiscover, arp-scan, unzip"
echo "   • Added user '$TARGET_USER' to group 'wireshark'"
echo "   • Created ./captures and ./scans"
echo
if is_wsl; then
  echo "ℹ️  WSL notes:"
  echo "   • You may need to open a NEW Windows Terminal tab (or run 'wsl --shutdown')"
  echo "     so the 'wireshark' group membership takes effect."
  echo "   • Your repo is visible from Windows at: \\\\wsl$\\kali-linux\\home\\$TARGET_USER\\kali-wsl-netlab"
else
  echo "ℹ️  VM/Host notes:"
  echo "   • If Wireshark prompts about permissions, ensure 'dumpcap' has the caps above."
fi
echo
echo "Try a quick capture once you reopen your terminal:"
echo "  bash scripts/capture/capture-progress.sh 50"
