# 5. Remove the separate Generate refresh tip

Date: 2026-06-10

## Status

Accepted

## Context

ADR 0003 requires a separate tip icon beside `Generate` while the action is disabled. The tip
repeats the refresh guidance already presented by the adjacent Bookmarknot `Refresh` control.

`Generate` and `Refresh` are distinct actions. Repeating the refresh tip beside `Generate` adds
visual clutter and can imply that the tip describes generation rather than the prerequisite
refresh action.

## Decision

`Generate` remains visible and disabled until its existing enablement conditions are met. It does
not have a separate tip icon when disabled.

The Bookmarknot section's `Refresh` control remains responsible for presenting the refresh hint:

```text
Refresh the list if it is empty now.
```

This decision supersedes only the separate `Generate` tip requirement in ADR 0003. The remaining
ADR 0003 decisions remain accepted and authoritative.

## Consequences

The Bookmarknot section has one refresh hint associated with the action it describes, reducing
duplicate controls and avoiding ambiguous help text beside `Generate`.

Users do not receive a second copy of the refresh hint from the disabled `Generate` control.
Product requirements and acceptance criteria must not require that separate tip.
