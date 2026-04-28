#!/bin/bash

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Repository hook dependency `jq` is required but not installed."},"systemMessage":"Repository hook dependency `jq` is required but not installed."}
EOF
  exit 0
fi

payload="$(cat)"
command_text="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"

if [[ "$command_text" == *"git"* ]] && [[ "$command_text" == *"commit"* ]] && [[ "$command_text" == *"--no-verify"* ]]; then
  jq -n \
    --arg reason "Repository policy blocks \`git commit --no-verify\`." \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      },
      systemMessage: $reason
    }'
fi
