#!/bin/bash

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  cat <<'EOF'
{"continue":false,"decision":"block","reason":"Repository hook dependency `jq` is required but not installed.","hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Install `jq` to enable Swift quality hooks."},"systemMessage":"Repository hook dependency `jq` is required but not installed."}
EOF
  exit 0
fi

payload="$(cat)"
repo_root="$(git rev-parse --show-toplevel)"
repo_slug="$(basename "$repo_root")"
tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
patch_text="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
cache_root="${TMPDIR:-/private/tmp}/${repo_slug}-codex-hooks"
clang_cache_dir="$cache_root/clang"
swiftlint_cache_dir="$cache_root/swiftlint"

declare -a swift_files=()

normalize_path() {
  local path="$1"

  if [[ -z "$path" ]]; then
    return 1
  fi

  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$repo_root" "$path"
  fi
}

add_swift_file() {
  local raw_path="$1"
  local normalized

  [[ "$raw_path" == *.swift ]] || return 0
  normalized="$(normalize_path "$raw_path")"
  [[ -f "$normalized" ]] || return 0

  local existing
  if [[ "${#swift_files[@]}" -gt 0 ]]; then
    for existing in "${swift_files[@]}"; do
      [[ "$existing" == "$normalized" ]] && return 0
    done
  fi

  swift_files+=("$normalized")
}

collect_apply_patch_files() {
  local line

  while IFS= read -r line; do
    case "$line" in
      "*** Add File: "*)
        add_swift_file "${line#*** Add File: }"
        ;;
      "*** Update File: "*)
        add_swift_file "${line#*** Update File: }"
        ;;
      "*** Move to: "*)
        add_swift_file "${line#*** Move to: }"
        ;;
    esac
  done <<<"$patch_text"
}

run_formatter() {
  local file

  for file in "${swift_files[@]}"; do
    swift-format format -i "$file"
  done
}

run_linter() {
  local file

  for file in "${swift_files[@]}"; do
    swiftlint lint --strict --cache-path "$swiftlint_cache_dir" "$file"
  done
}

run_typechecker() {
  local file

  for file in "${swift_files[@]}"; do
    swiftc -typecheck "$file"
  done
}

emit_block() {
  local reason="$1"
  local details="${2:-}"

  jq -n \
    --arg reason "$reason" \
    --arg details "$details" \
    '{
      continue: false,
      systemMessage: $reason,
      decision: "block",
      reason: $reason,
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: $details
      }
    }'
}

main() {
  if [[ "$tool_name" != "apply_patch" ]]; then
    exit 0
  fi

  collect_apply_patch_files

  if [[ "${#swift_files[@]}" -eq 0 ]]; then
    exit 0
  fi

  local missing=()
  local tool
  for tool in jq swift-format swiftlint swiftc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    emit_block \
      "Swift quality checks could not run because required tools are missing." \
      "Missing tools: ${missing[*]}. Touched Swift files: ${swift_files[*]}"
    exit 0
  fi

  mkdir -p "$clang_cache_dir" "$swiftlint_cache_dir"

  local failure_output
  failure_output="$(
    {
      export CLANG_MODULE_CACHE_PATH="$clang_cache_dir"
      run_formatter
      run_linter
      run_typechecker
    } 2>&1
  )" || {
    emit_block \
      "Swift quality checks failed after this edit." \
      "$failure_output"
    exit 0
  }
}

main
