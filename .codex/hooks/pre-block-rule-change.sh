#!/bin/bash

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Repository hook dependency `jq` is required but not installed."},"systemMessage":"Repository hook dependency `jq` is required but not installed."}
EOF
  exit 0
fi

payload="$(cat)"

emit_deny() {
  local target="$1"
  local reason="$2"

  jq -n \
    --arg reason "$reason" \
    --arg target "$target" \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      },
      systemMessage: ($reason + " Target: " + $target)
    }'
}

is_protected_path() {
  local path="$1"

  [[ -n "$path" ]] || return 1

  case "$path" in
    .codex|.codex/*|*/.codex|*/.codex/*|.swift-format|*/.swift-format|.swiftlint.yml|*/.swiftlint.yml)
      return 0
      ;;
  esac

  return 1
}

check_path() {
  local path="$1"

  if is_protected_path "$path"; then
    emit_deny \
      "$path" \
      "Protected repository config files cannot be modified. Fix code instead of changing repo-local hooks or lint/format config."
    exit 0
  fi
}

collect_apply_patch_paths() {
  local patch_text="$1"
  local line

  while IFS= read -r line; do
    case "$line" in
      "*** Add File: "*)
        check_path "${line#*** Add File: }"
        ;;
      "*** Update File: "*)
        check_path "${line#*** Update File: }"
        ;;
      "*** Delete File: "*)
        check_path "${line#*** Delete File: }"
        ;;
      "*** Move to: "*)
        check_path "${line#*** Move to: }"
        ;;
    esac
  done <<<"$patch_text"
}

main() {
  local tool_name
  tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"

  case "$tool_name" in
    Write|Edit|MultiEdit)
      check_path "$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // ""')"
      ;;
    apply_patch)
      collect_apply_patch_paths "$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
      ;;
  esac
}

main
