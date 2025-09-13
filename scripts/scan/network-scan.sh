
#!/usr/bin/env bash
# network-scan.sh — safe LAN discovery using nmap
# Usage:
#   ./network-scan.sh 192.168.1.0/24
#   ./network-scan.sh 192.168.1.0/24 --services

set -euo pipefail
CIDR=${1:-}
MODE=${2:-}

if [[ -z "$CIDR" ]]; then
  echo "Usage: $0 <CIDR e.g., 192.168.1.0/24> [--services]"
  exit 1
fi

mkdir -p "$(pwd)/scans"
TS=$(date +"%Y%m%d-%H%M%S")
OUT="scans/scan-${TS}.txt"

echo "[*] Discovering live hosts on ${CIDR} ..."
nmap -sn "$CIDR" -oN "$OUT"

if [[ "$MODE" == "--services" ]]; then
  echo "[*] Enumerating services on live hosts ..."
  IPS=$(awk '/Nmap scan report/{ip=$NF} /Host is up/{print ip}' "$OUT" | tr -d '()')
  if [[ -n "$IPS" ]]; then
    echo "[*] Running -sV on: $IPS"
    nmap -sV $IPS >> "$OUT"
  else
    echo "[!] No live hosts found from ping sweep." >> "$OUT"
  fi
fi

echo "[+] Report saved: $(pwd)/${OUT}"
