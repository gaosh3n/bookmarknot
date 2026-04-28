#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly MAX_SUBJECT_LENGTH=72
readonly ALLOWED_TYPES=(feat fix docs refactor test chore)

emit_failure() {
  local problem="$1"

  cat >&2 <<EOF
Invalid git commit message.

Required format:
  <type>: <summary>

Allowed types:
  feat, fix, docs, refactor, test, chore

Rules:
  - enforced only for COMMIT_EDITMSG
  - exactly one non-comment line
  - no blank lines
  - no trailers
  - separator must be exactly ": "
  - no leading or trailing whitespace
  - no trailing period
  - ${MAX_SUBJECT_LENGTH} characters max

Problem:
  ${problem}
EOF

  exit 1
}

allowed_type() {
  local candidate="$1"
  local allowed

  for allowed in "${ALLOWED_TYPES[@]}"; do
    if [[ "$candidate" == "$allowed" ]]; then
      return 0
    fi
  done

  return 1
}

main() {
  local message_file="${1:-}"

  if [[ -z "$message_file" ]]; then
    emit_failure "${SCRIPT_NAME} expected the commit message file path."
  fi

  if [[ ! -f "$message_file" ]]; then
    emit_failure "commit message file does not exist: ${message_file}"
  fi

  case "$(basename "$message_file")" in
    COMMIT_EDITMSG)
      ;;
    MERGE_MSG|SQUASH_MSG)
      exit 0
      ;;
    *)
      exit 0
      ;;
  esac

  local -a subject_lines=()
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == \#* ]]; then
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*$ ]]; then
      emit_failure "found a blank non-comment line."
    fi

    if [[ "${#subject_lines[@]}" -ge 1 ]] && [[ "$line" =~ ^(Co-authored-by|Signed-off-by):[[:space:]]+ ]]; then
      emit_failure "found a prohibited trailer line: ${line}"
    fi

    subject_lines+=("$line")
  done < "$message_file"

  if [[ "${#subject_lines[@]}" -ne 1 ]]; then
    emit_failure "found ${#subject_lines[@]} non-comment lines; exactly 1 is required."
  fi

  local subject="${subject_lines[0]}"

  if [[ "$subject" =~ ^[[:space:]] || "$subject" =~ [[:space:]]$ ]]; then
    emit_failure "subject must not start or end with whitespace."
  fi

  if [[ ${#subject} -gt ${MAX_SUBJECT_LENGTH} ]]; then
    emit_failure "subject is ${#subject} characters long; max is ${MAX_SUBJECT_LENGTH}."
  fi

  if [[ "$subject" != *:* ]]; then
    emit_failure "missing type separator; expected \"<type>: <summary>\"."
  fi

  local type="${subject%%:*}"
  local after_colon="${subject#*:}"

  if [[ "$type" =~ [[:space:]]$ ]] || [[ "$after_colon" != " "* ]] || [[ "$after_colon" == "  "* ]]; then
    emit_failure "separator must be exactly \": \" with no space before the colon and one space after it."
  fi

  if ! allowed_type "$type"; then
    emit_failure "type must be one of: feat, fix, docs, refactor, test, chore."
  fi

  local summary="${after_colon# }"

  if [[ -z "$summary" ]]; then
    emit_failure "summary must not be empty."
  fi

  if [[ "$summary" =~ ^[[:space:]] || "$summary" =~ [[:space:]]$ ]]; then
    emit_failure "summary must not start or end with whitespace."
  fi

  if [[ "$summary" == *"." ]]; then
    emit_failure "summary must not end with a period."
  fi
}

main "$@"
