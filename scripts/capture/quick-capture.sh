
#!/usr/bin/env bash
# quick-capture.sh — simple 100-packet capture into ./captures

set -euo pipefail
mkdir -p "$(pwd)/captures"
TS=$(date +"%Y%m%d-%H%M%S")
OUT="captures/capture-${TS}.pcap"

echo "[*] Capturing 100 packets to $(pwd)/${OUT} ..."
tshark -c 100 -w "${OUT}"
echo "[+] Capture saved: $(pwd)/${OUT}"
