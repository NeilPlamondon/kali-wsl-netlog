
#!/usr/bin/env bash
# capture-progress.sh — tshark capture with a blue progress bar
# Usage: ./capture-progress.sh [count] [iface] [filter...]

set -euo pipefail

COUNT=${1:-100}
# Auto-detect primary interface (fallback eth0)
IFACE=${2:-$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if ($i=="dev"){print $(i+1); exit}}')}
IFACE=${IFACE:-eth0}

shift || true
shift || true
FILTER_ARGS=("$@")

mkdir -p "$(pwd)/captures"
TS=$(date +"%Y%m%d-%H%M%S")
OUT="captures/capture-${TS}.pcap"

echo "[*] Capturing ${COUNT} packets on '${IFACE}' -> $(pwd)/${OUT}"
[[ ${#FILTER_ARGS[@]} -gt 0 ]] && echo "    Filter: ${FILTER_ARGS[*]}"
echo "    (Ctrl+C to stop early)"

draw_bar() {
  local cur=$1 total=$2
  local width=50
  local filled=$(( cur * width / total ))
  local empty=$(( width - filled ))
  local blue="\033[34m"
  local reset="\033[0m"
  printf "\r[%b%s%b%s] %3d%% (%d/%d)" \
    "$blue" "$(printf '%*s' "$filled" | tr ' ' '#')" \
    "$reset" "$(printf '%*s' "$empty" | tr ' ' ' ')" \
    $(( cur * 100 / total )) "$cur" "$total"
}

i=0
# Force per-packet output with -V; line-buffer with -l; print summaries with -P
# shellcheck disable=SC2086
tshark -i "$IFACE" -l -P -V -c "$COUNT" -w "$OUT" ${FILTER_ARGS[@]+"${FILTER_ARGS[@]}"} 2>/dev/null \
| grep --line-buffered "^Frame " \
| while read -r _; do
    i=$((i+1))
    draw_bar "$i" "$COUNT"
  done

echo
echo "✅ Saved: $(pwd)/${OUT}"
echo "Tip: view with: tshark -r \"${OUT}\""
