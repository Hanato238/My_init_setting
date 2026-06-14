#!/bin/bash
# Claude Code Stop hook — ~/.claude/stats.json を更新する
# Claude Code のフックとして呼ばれ、stdin に JSON ペイロードを受け取る
payload=$(cat)
stats_file="$HOME/.claude/stats.json"

model=$(echo "$payload" | jq -r '.model // "unknown"' 2>/dev/null)
tokens_used=$(echo "$payload" | jq -r '.usage.input_tokens // empty' 2>/dev/null)
tokens_max=$(echo "$payload" | jq -r '.usage.cache_read_input_tokens // empty' 2>/dev/null)

turn_count=$(jq -r '.turn_count // 0' "$stats_file" 2>/dev/null)
turn_count=$((${turn_count:-0} + 1))

jq -n \
  --arg model "${model:-unknown}" \
  --argjson tokens_used "${tokens_used:-null}" \
  --argjson tokens_max "${tokens_max:-null}" \
  --argjson turn_count "$turn_count" \
  '{model: $model, tokens_used: $tokens_used, tokens_max: $tokens_max, turn_count: $turn_count}' \
  > "$stats_file"
