# 6. Expand Runtime Log to include normal activity levels

Date: 2026-06-11

## Status

Accepted

## Context

ADR 0003 defines Runtime Log as a live, file-backed, user-visible surface, but it narrows the
live updates to "runtime errors and exceptions". That framing is too restrictive for the product
need.

Runtime Log is not only for failure diagnosis. It is also a user-visible trace of the app's
normal activity so users can understand what the app is doing over time. Examples include refresh
starts and completions, generation starts and completions, partial refresh warnings, and runtime
failures.

Without levelled logging, the product cannot distinguish routine activity from warning or error
conditions. Without explicit product language, issue requirements and implementation work can drift
back to an errors-only interpretation.

## Decision

Runtime Log remains the single visible, file-backed runtime log for the MVP, stored under:

```text
~/Library/Application Support/Bookmarknot/logs/
```

The Runtime Log records significant runtime activity, not only exceptions and errors. It is a
user-visible trace of app behavior.

The MVP Runtime Log uses three logging levels:

- `INFO` for normal activity that helps the user trace what the app did.
- `WARN` for recoverable or partial-failure situations.
- `ERROR` for failures and exceptions.

The visible Runtime Log panel remains read-only text and continues to update live as new log
entries are appended.

`Clean` continues to truncate the visible runtime log content immediately without deleting the log
file.

Pop-up dialogs still avoid technical detail. Technical detail belongs in Runtime Log regardless of
entry level.

This decision supersedes only the errors-and-exceptions-only interpretation in ADR 0003's Runtime
Log section. All other ADR 0003 decisions remain accepted and authoritative.

## Consequences

The product can expose meaningful normal activity in Runtime Log without pretending every entry is
an error.

Future runtime-log implementation work should encode level information in log entries and choose
`INFO` events deliberately so the log stays useful rather than noisy.

Issue requirements and tests for Runtime Log should cover normal activity visibility in addition to
warning and error handling.
