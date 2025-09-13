
#!/usr/bin/env bash
set -euo pipefail

command -v tshark >/dev/null 2>&1 || { echo "tshark not found. Install with: sudo apt update && sudo apt install -y tshark"; exit 1; }

mkdir -p "$HOME/captures"
TS=$(date +"%Y%m%d-%H%M%S")

echo "=== Quick Capture Menu ==="
echo
tshark -D || { echo "Couldn't list interfaces"; exit 1; }
echo
read -rp "Select interface number (e.g., 1): " IFNUM
IFACE=$(tshark -D 2>/dev/null | awk -v n="$IFNUM" -F'[). ]' 'NR==n {print $3}')
[[ -z "${IFACE:-}" ]] && { echo "Invalid selection"; exit 1; }

echo
echo "Mode:"
echo "  1) Packet count"
echo "  2) Duration (seconds)"
read -rp "Choose 1 or 2: " MODE

COUNT_ARG=""; DUR_ARG=""
case "$MODE" in
  1) read -rp "How many packets? (default 100): " CNT; CNT=${CNT:-100}; COUNT_ARG="-c ${CNT}" ;;
  2) read -rp "How many seconds? (default 30): " SEC; SEC=${SEC:-30}; DUR_ARG="-a duration:${SEC}" ;;
  *) echo "Invalid mode"; exit 1;;
esac

echo
echo "Optional capture filter (BPF), e.g. 'port 443' or 'host 192.168.1.1'"
read -rp "Filter (blank for none): " FILTER
FILTER_ARG=()
[[ -n "${FILTER}" ]] && FILTER_ARG=( "${FILTER}" )

read -rp "Output name (blank = auto): " NAME
[[ -z "${NAME}" ]] && NAME="capture-${TS}"
OUT="$HOME/captures/${NAME}.pcap"

echo
echo "Interface : ${IFACE}"
[[ -n "$COUNT_ARG" ]] && echo "Packets   : ${CNT}"
[[ -n "$DUR_ARG" ]] && echo "Duration  : ${SEC}s"
[[ -n "$FILTER" ]] && echo "Filter    : ${FILTER}"
echo "Output    : ${OUT}"
echo
echo "Press Ctrl+C to stop early."
# shellcheck disable=SC2086
tshark -i "${IFACE}" -l -P ${COUNT_ARG} ${DUR_ARG} -w "${OUT}" ${FILTER_ARG[@]+"${FILTER_ARG[@]}"} 
echo "✅ Saved: ${OUT}"
