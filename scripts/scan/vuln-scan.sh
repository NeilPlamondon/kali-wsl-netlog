#!/usr/bin/env bash
# vuln-scan.sh — discover hosts, then run nmap vuln scripts per host
# Plus: auto-run Nikto against HTTP/HTTPS services discovered by Nmap.
# Usage:
#   sudo bash scripts/scan/vuln-scan.sh 192.168.1.0/24
# Options:
#   --top-ports N   scan only top N ports (faster) instead of -p-
#   --rate X        nmap min packet rate (e.g., 200)
#   --out DIR       output directory (default: scans)
# Notes: Only scan networks you own/have permission to test.

set -euo pipefail

CIDR="${1:-}"
shift || true
TOPPORTS=""
RATE=""
OUTDIR="scans"

while (( "$#" )); do
  case "$1" in
    --top-ports)  TOPPORTS="--top-ports ${2:-1000}"; shift 2;;
    --rate)       RATE="--min-rate ${2:-100}";       shift 2;;
    --out)        OUTDIR="${2:-scans}";              shift 2;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [[ -z "$CIDR" ]]; then
  echo "Usage: sudo bash scripts/scan/vuln-scan.sh <CIDR or space-separated IPs> [--top-ports N] [--rate X] [--out DIR]"
  exit 1
fi

command -v nmap  >/dev/null 2>&1 || { echo "nmap not found. Install with: sudo apt install -y nmap"; exit 1; }
command -v nikto >/dev/null 2>&1 || echo "[!] nikto not found (web vulns will be skipped). Install with: sudo apt install -y nikto"

mkdir -p "$OUTDIR"
SUMMARY="$OUTDIR/summary-$(date +%Y%m%d-%H%M%S).csv"
echo "ip,open_ports,vuln_findings,nikto_targets,file" > "$SUMMARY"

echo "[1/3] Discovering live hosts on: $CIDR"
# Accept either a CIDR or space-separated IPs
if [[ "$CIDR" == *"/"* ]]; then
  LIVE=$(sudo nmap -sn -PE -PA21,22,80,443,3389 "$CIDR" -oG - | awk '/Up$/{print $2}')
else
  # treat args as explicit IPs; test each with a quick ping probe
  LIVE=""
  for ip in $CIDR; do
    if sudo nmap -sn -PE "$ip" -oG - | awk '/Up$/{exit 0} END{exit 1}'; then
      LIVE+="$ip"$'\n'
    fi
  done
fi

if [[ -z "$LIVE" ]]; then
  echo "[!] No live hosts found."
  exit 0
fi
echo "$LIVE" | sed 's/^/  - /'

echo "[2/3] Service + vuln scan …"
for IP in $LIVE; do
  OUT="$OUTDIR/${IP}-vuln.txt"
  echo "→ $IP"

  PORTSEL="-p-"
  [[ -n "$TOPPORTS" ]] && PORTSEL="$TOPPORTS"

  # 1) Service detection, gather open ports
  sudo nmap -sV $PORTSEL -Pn --open $RATE "$IP" -oN "$OUT" >/dev/null 2>&1 || true

  # 2) Vulnerability scripts (append)
  if grep -qE 'open' "$OUT"; then
    {
      echo
      echo "===== Nmap vuln scripts ====="
      sudo nmap -sV $PORTSEL -Pn --script vuln $RATE "$IP"
    } >> "$OUT" 2>/dev/null || true
  fi

  # 3) If nikto is present, run against any http/https services discovered
  NIKTO_TARGETS=""
  if command -v nikto >/dev/null 2>&1; then
    # Find lines with open ports that mention http or ssl/https
    # Example lines:
    # 80/tcp  open  http
    # 443/tcp open  ssl/https
    mapfile -t WEBLINES < <(awk '/open/ && /http/ {print}' "$OUT")
    if ((${#WEBLINES[@]})); then
      echo >> "$OUT"
      echo "===== Nikto web scan =====" >> "$OUT"
      for line in "${WEBLINES[@]}"; do
        port=$(awk '{print $1}' <<<"$line" | cut -d'/' -f1)
        lower=$(tr '[:upper:]' '[:lower:]' <<<"$line")
        scheme="http"
        [[ "$lower" == *"ssl/https"* || "$lower" == *"https"* ]] && scheme="https"
        url="${scheme}://${IP}:${port}/"
        NIKTO_TARGETS+="${url} "
        echo "--- nikto -h $url ---" >> "$OUT"
        nikto -h "$url" -ask=no -nointeractive >> "$OUT" 2>&1 || true
        echo >> "$OUT"
      done
    fi
  fi

  # 4) Summarize to CSV
  PORTS=$(awk '/open/{print $1}' "$OUT" | cut -d'/' -f1 | paste -sd';' -)
  VULNCOUNT=$(grep -cE 'VULNERABLE|CVE-|vuln\.' "$OUT" || true)
  echo "${IP},\"${PORTS}\",${VULNCOUNT},\"${NIKTO_TARGETS}\",${OUT}" >> "$SUMMARY"
done

echo "[3/3] Done."
echo "• Per-host reports: $OUTDIR/<IP>-vuln.txt"
echo "• Summary CSV: $SUMMARY"
echo
echo "Examples:"
echo "  sudo bash scripts/scan/vuln-scan.sh 192.168.1.0/24 --top-ports 200 --rate 300"
echo "  sudo bash scripts/scan/vuln-scan.sh 192.168.1.100 192.168.1.115"
