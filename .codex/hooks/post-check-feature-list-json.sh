#!/bin/bash

set -euo pipefail

payload="$(cat)"
repo_root="$(git rev-parse --show-toplevel)"
tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
patch_text="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
feature_file="$repo_root/feature_list.json"
schema_file="$repo_root/.codex/schemas/feature_list.schema.json"

affects_feature_list() {
  local path="$1"

  case "$path" in
    feature_list.json|./feature_list.json)
      return 0
      ;;
  esac

  return 1
}

collect_apply_patch_paths() {
  local line

  while IFS= read -r line; do
    case "$line" in
      "*** Add File: "*)
        affects_feature_list "${line#*** Add File: }" && return 0
        ;;
      "*** Update File: "*)
        affects_feature_list "${line#*** Update File: }" && return 0
        ;;
      "*** Move to: "*)
        affects_feature_list "${line#*** Move to: }" && return 0
        ;;
    esac
  done <<<"$patch_text"

  return 1
}

emit_block() {
  local reason="$1"
  local details="${2:-}"

  jq -n \
    --arg reason "$reason" \
    --arg details "$details" \
    '{
      continue: false,
      decision: "block",
      reason: $reason,
      systemMessage: $reason,
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: $details
      }
    }'
}

should_validate() {
  [[ "$tool_name" == "apply_patch" ]] || return 1
  collect_apply_patch_paths
}

format_feature_list() {
  local tmp_file
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/feature-list.XXXXXX.json")"

  jq '.' "$feature_file" > "$tmp_file" || {
    rm -f "$tmp_file"
    return 1
  }

  mv "$tmp_file" "$feature_file"
}

main() {
  if ! command -v jq >/dev/null 2>&1; then
    emit_block "feature_list.json schema validation could not run because jq is missing."
    exit 0
  fi

  if ! should_validate; then
    exit 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    emit_block "feature_list.json schema validation could not run because python3 is missing."
    exit 0
  fi

  local import_output
  import_output="$({ python3 - <<'PY'
import jsonschema
print("jsonschema-ok")
PY
  } 2>&1)" || {
    emit_block \
      "feature_list.json schema validation could not run because Python could not import 'jsonschema'." \
      "$import_output"
    exit 0
  }

  if [[ ! -f "$schema_file" ]]; then
    emit_block "feature_list.json schema validation could not run because the schema file is missing." "$schema_file"
    exit 0
  fi

  if [[ ! -f "$feature_file" ]]; then
    emit_block "feature_list.json schema validation could not run because the canonical root feature_list.json file is missing." "$feature_file"
    exit 0
  fi

  local validation_output
  validation_output="$({ python3 - "$feature_file" "$schema_file" <<'PY'
import json
import sys
from jsonschema import Draft202012Validator

feature_path = sys.argv[1]
schema_path = sys.argv[2]

with open(feature_path, 'r', encoding='utf-8') as fh:
    instance = json.load(fh)

with open(schema_path, 'r', encoding='utf-8') as fh:
    schema = json.load(fh)

validator = Draft202012Validator(schema)
errors = sorted(validator.iter_errors(instance), key=lambda err: list(err.absolute_path))
if errors:
    err = errors[0]
    path = ''.join(
        f'[{part}]' if isinstance(part, int) else (part if i == 0 else f'.{part}')
        for i, part in enumerate(err.absolute_path)
    ) or '$'
    print(f'{path}: {err.message}')
    sys.exit(1)
PY
  } 2>&1)" || {
    emit_block "feature_list.json does not match .codex/schemas/feature_list.schema.json." "$validation_output"
    exit 0
  }

  local format_output
  format_output="$({ format_feature_list; } 2>&1)" || {
    emit_block "feature_list.json passed schema validation but jq formatting failed." "$format_output"
    exit 0
  }
}

main
