#!/usr/bin/env bash
# Claude Code status line.
#
# Reads the status line JSON Claude Code pipes to stdin and renders:
#   <model display name> | <context usage meter> | <cwd basename> (<git branch>)
#
# Git commands use --no-optional-locks so they never contend with a
# concurrently running git process.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

dir_name=""
if [ -n "$cwd" ]; then
  dir_name=$(basename "$cwd")
fi

branch=""
if [ -n "$cwd" ]; then
  branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
fi

# Format a raw token count as e.g. "12.3k" or "1.2M".
fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { printf "%.1fM", n/1000000 }
    else if (n >= 1000) { printf "%.1fk", n/1000 }
    else { printf "%d", n }
  }'
}

# Build a 10-segment context usage meter.
meter=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  filled=$(awk -v p="$used_pct" 'BEGIN { f = int(p/10 + 0.5); if (f > 10) f = 10; if (f < 0) f = 0; print f }')
  empty=$((10 - filled))
  # tr operates byte-by-byte and mangles multi-byte UTF-8 chars like █/░, so
  # build the bar with awk instead (string literals pass through byte-transparent).
  bar=$(awk -v f="$filled" -v e="$empty" 'BEGIN { s=""; for (i=0;i<f;i++) s=s"█"; for (i=0;i<e;i++) s=s"░"; print s }')
  pct_display=$(printf '%.0f' "$used_pct")
  meter="${bar} ${pct_display}%"
  if [ -n "$total_tokens" ] && [ "$total_tokens" != "null" ] && [ -n "$window_size" ] && [ "$window_size" != "null" ]; then
    meter="${meter} ($(fmt_tokens "$total_tokens")/$(fmt_tokens "$window_size"))"
  fi
elif [ -n "$total_tokens" ] && [ "$total_tokens" != "null" ] && [ -n "$window_size" ] && [ "$window_size" != "null" ] && [ "$window_size" != "0" ]; then
  pct_display=$(awk -v t="$total_tokens" -v w="$window_size" 'BEGIN { printf "%.0f", (t/w)*100 }')
  meter="${pct_display}% ($(fmt_tokens "$total_tokens")/$(fmt_tokens "$window_size"))"
else
  meter="new session"
fi

# Dimmed ANSI colors (the status line is rendered dim by the terminal).
DIM='\033[2m'
CYAN='\033[2;36m'
YELLOW='\033[2;33m'
GREEN='\033[2;32m'
RESET='\033[0m'

out="${CYAN}${model}${RESET}"
out="${out} ${DIM}|${RESET} ${YELLOW}${meter}${RESET}"

if [ -n "$dir_name" ]; then
  out="${out} ${DIM}|${RESET} ${GREEN}${dir_name}${RESET}"
fi

if [ -n "$branch" ]; then
  out="${out} ${DIM}(${branch})${RESET}"
fi

printf "%b" "$out"
