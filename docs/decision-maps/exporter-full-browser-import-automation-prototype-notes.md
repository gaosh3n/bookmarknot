# Full Browser Import Automation Prototype Notes

Date: 2026-06-24

## Question

Can Bookmarknot import preselected bookmark HTML into the user's existing logged-in Chrome and Safari profiles using browser-owned UI, explicit macOS permissions, and no human interaction after permission grant?

Correction after the live session: Chrome met that bar. Safari completed only after the user satisfied a password/Touch ID challenge during import.

## Inputs

- Chrome: `~/Desktop/browser-chrome.html`
- Safari: `~/Desktop/browser-safari.html`

Both files existed before testing and remained present afterward.

## Environment

- macOS `26.5.1` (`25F80`)
- Safari `26.5`
- running Google Chrome `149.0.7827.114`
- preferred languages: `en-US`, then `zh-Hans-US`
- both browsers already running with multiple windows
- `System Events` reported UI scripting enabled

## Chrome Result

Successful route:

1. Activate Chrome and create a new normal window in the current running browser.
2. Open `chrome://bookmarks/`.
3. Enable Chrome's per-process enhanced Accessibility tree.
4. Wait for the bookmark-manager tab to finish loading.
5. Move Accessibility focus to the `Organize` pop-up button.
6. Select `Import bookmarks`.
7. In the attached standard file panel, use Go to Folder and the fixed Chrome HTML path.
8. Confirm the selection and wait for the file panel to close.

Observed outcomes:

- ad hoc prototype completed with exit zero
- Chrome bookmark-store persistence lagged UI completion by about one second
- retained probe completed with exit zero
- retained-probe store timestamp changed from `2026-06-24T07:49:43Z` to `2026-06-24T07:53:36Z`
- the first cold-start attempt returned nonzero because Chrome's renderer Accessibility tree was not enabled
- after making enhanced Accessibility and tab-loading readiness explicit, a cold-start run completed with exit zero and changed the store timestamp from `2026-06-24T07:58:22Z` to `2026-06-24T07:59:59Z`

Chrome did not expose a browser-owned success event through AppleScript. Under the accepted contract, deterministic UI completion is sufficient; store modification remains supporting evidence.

## Safari Result

Successful route:

1. Activate Safari.
2. Invoke `File > Import Browsing Data from File or Folder…`.
3. Click `Choose File or Folder…` in Safari's introductory dialog.
4. In the standard `Import File` panel, use Go to Folder and the fixed Safari HTML path.
5. Confirm the selection.
6. Safari presents an interactive password/Touch ID authorization challenge.
7. The user satisfies that challenge.
8. Wait for Safari's `Import Successful` alert.
9. Click `Done`.
10. When Safari offers to delete the imported source, click `Not Now`.

Observed outcomes:

- Safari reported `Safari has successfully imported 160 bookmarks.`
- the user explicitly intervened to satisfy Safari's password/Touch ID challenge
- the prototype therefore demonstrated assisted automation, not unattended full automation for Safari
- the first retained-probe attempt correctly returned nonzero because the asynchronous success/delete sequence had not yet been modeled
- the corrected retained probe completed with exit zero
- Safari's bookmark store changed from `2026-06-23T11:05:37Z` to `2026-06-24T07:54:51Z`
- the preselected Safari HTML file remained present

## Durable Prototype

The successful state machines were absorbed into:

- `Sources/FullBrowserImportAutomationProbe/main.swift`
- SwiftPM executable `full-browser-import-automation-probe`

The preflight is documented in `AGENTS.md`. Live `chrome` and `safari` modes intentionally remain decision-map tooling rather than general test commands because they mutate the user's real browser profile.

The preflight now also performs a non-mutating Chrome Bookmarks Bar cleanup capability check. It opens `chrome://bookmarks/?id=1` in a selected normal Chrome window, enables Chrome's enhanced Accessibility tree, verifies the `Organize` control and `Bookmarks Bar` row are reachable by keyboard Accessibility focus, then closes the selected window only if preflight created it.

The Chrome live automation now selects one normal Chrome window at the start of the run. It reuses an existing normal window when available, opens one only when needed, and runs Bookmarks Bar cleanup plus import through that same window. The preflight follows the same lifecycle rule for capability checks and reports whether it reused or opened a window.

## Limits

- The prototype depends on English Accessibility labels and current menu structure.
- macOS permissions were already granted for the prototyping execution host, so first-grant UI was not reset or retested.
- Safari interactive authorization occurred after file selection and could not be covered by preflight.
- A final packaged Bookmarknot executable will have a different TCC identity and must perform its own permission preflight.
- Locked sessions, active user interference, future browser versions, non-English UI, and ambiguous multi-profile Chrome state require explicit compatibility validation.
