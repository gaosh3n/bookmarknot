## #1: Define Full Browser Import Automation

Blocked by: none
Type: Discuss

### Question

What must Bookmarknot do for a browser-import run to count as full automation, and which constraints from the earlier guided-handoff decision are being reopened?

### Answer

Resolved through grilling.

- Input is one preselected, valid browser-importable bookmark `HTML` file.
- The target is the user's existing logged-in Chrome or Safari profile. Bookmarknot must not create or switch to another browser profile.
- The browser may already be open, or automation may open a new browser window when required.
- After the user grants any macOS permissions that cannot be granted earlier, the import completes without further human interaction.
- The automation must invoke a browser-owned import path. Directly rewriting the browser bookmark store is not part of this investigation.
- A zero process exit status is sufficient evidence that the automated procedure completed. A nonzero status is failure.
- Browser bookmark-store modification time may be recorded as supporting evidence, with latency allowed, but content-level verification is not required.
- Sandboxing is not a feasibility constraint. A helper process, CLI, AppleScript application, Shortcuts workflow, or equivalent macOS component may participate.
- Prototypes may target the user's current browser profiles; the user is responsible for backups.

Evidence correction:

- Chrome met this definition in the tested environment.
- Safari did not: it required interactive password/Touch ID authorization after file selection.
- The accepted product scope now permits that single interactive authorization step for Safari, making Safari an assisted browser import rather than full automation.

Relationship to [exporter-how-to-interact.md](./exporter-how-to-interact.md):

- the prior guided handoff was the known fallback during this feasibility investigation; the later wizard redesign removed it from the product contract
- this map reopens only the claim that browser import cannot be fully automated
- the exporter UX and status model should not be revised until an end-to-end automation route is demonstrated

## #2: Inventory macOS Automation Surfaces And Permission Gates

Blocked by: #1
Type: Research

### Question

Which macOS-native or macOS-relevant mechanisms can drive browser menus, browser-owned import UI, file selection, and confirmation for Chrome and Safari, and what runtime permission, TCC, process, localization, focus, and session-state constraints does each mechanism impose?

### Answer

Resolved in [exporter-full-browser-import-automation-research.md](./exporter-full-browser-import-automation-research.md).

- Neither installed browser dictionary exposes bookmark `HTML` import.
- AppleScript plus `System Events` is the fastest viable prototype route because it can drive browser menus and the standard file panel through Accessibility.
- A direct `AXUIElement` implementation has the same Accessibility capability with stronger discovery, timeout, and error handling; it is the preferred production candidate if UI scripting proves feasible.
- Synthetic keyboard/mouse events are a narrow fallback, not the first route.
- `osascript`, OSAKit, ScriptingBridge, helpers, Automator, and Shortcuts are execution hosts. They do not remove Apple Events or Accessibility permission gates.
- Chrome DevTools Protocol and Safari WebDriver automate web content, not browser chrome or bookmark import.
- The prototype frontier is Chrome ticket `#3` and Safari ticket `#4`, using `System Events` first and direct Accessibility only where needed.

## #3: Prototype Chrome Import Through The Strongest Native Route

Blocked by: #2
Type: Prototype

### Question

Can a permission-granted macOS automation procedure import the preselected `HTML` file into the active logged-in Chrome profile, whether Chrome starts closed or already has windows open, and return a trustworthy exit status without post-permission human input?

### Answer

Resolved in [exporter-full-browser-import-automation-prototype-notes.md](./exporter-full-browser-import-automation-prototype-notes.md).

- Full automation succeeded against the already-running, logged-in Chrome profile using `~/Desktop/browser-chrome.html`.
- A later cold-start run also succeeded after the probe enabled Chrome's per-process enhanced Accessibility tree and waited for the bookmark-manager tab to finish loading.
- The route creates a new normal Chrome window, opens `chrome://bookmarks/`, locates the `Organize` Accessibility control, invokes `Import bookmarks`, and drives the standard file panel.
- The retained probe returned zero only after the file panel closed.
- Chrome's active-profile bookmark store changed shortly afterward and also changed during the retained-probe run.
- Missing controls, missing file panels, timeouts, and script errors return nonzero.

## #4: Prototype Safari Import Through The Strongest Native Route

Blocked by: #2
Type: Prototype

### Question

Can a permission-granted macOS automation procedure import the preselected `HTML` file into the active logged-in Safari profile, whether Safari starts closed or already has windows open, and return a trustworthy exit status without post-permission human input?

### Answer

Resolved with a positive result for assisted browser import in [exporter-full-browser-import-automation-prototype-notes.md](./exporter-full-browser-import-automation-prototype-notes.md).

- The automated route reached Safari's import operation against the already-running, logged-in profile using `~/Desktop/browser-safari.html`.
- The route invokes `File > Import Browsing Data from File or Folder…`, advances through Safari's introductory dialog, and drives the standard `Import File` panel.
- Safari then presented a password/Touch ID challenge. The user manually satisfied it.
- Safari asynchronously reported `Import Successful` for `160 bookmarks`.
- The route clicks `Done`, then selects `Not Now` when Safari offers to delete the source HTML, preserving the preselected file.
- The retained probe returned zero after Safari reported success and the source-file retention prompt completed, and Safari's bookmark store changed.
- That zero exit did not prove unattended completion because it depended on the user's unrecorded interactive authorization.
- Under the accepted assisted-automation contract, the observed Touch ID/password action is permitted and every other Safari step remains automated.

## #5: Define Permission Acquisition And Resume Semantics

Blocked by: #2, #3, #4
Type: Discuss

### Question

When Automation, Accessibility, or other permission is missing at runtime, how should Bookmarknot request it, detect the resulting authorization state, and resume or restart the same import without requiring the user to repeat unrelated steps?

### Answer

Resolved.

- macOS may require Automation consent for the execution host to send Apple Events to `System Events` and Accessibility consent to control browser UI.
- Bookmarknot cannot grant either permission itself.
- The non-mutating `preflight` command is the permission and input check. It returns nonzero if Accessibility UI scripting is disabled, Apple Events are denied, either input is missing, or a browser is not installed.
- If macOS presents a permission prompt, the user grants it and reruns the operation. No unrelated selection or preparation step is repeated because the export path is fixed before preflight.
- A production app or stable signed helper must own the automation consistently. TCC approval granted to Terminal during prototyping must not be assumed to transfer to Bookmarknot.
- Safari's password/Touch ID prompt is interactive authorization, not a TCC permission grant. It occurred after file selection and was not discoverable through the existing preflight.
- Chrome required no further human interaction after permission grant. Safari did.

## #6: Test State And Environment Robustness

Blocked by: #3, #4
Type: Prototype

### Question

Across which browser and macOS states does each proven route remain deterministic, and which states must be rejected by preflight rather than producing ambiguous automation?

### Answer

Resolved for the demonstrated environment; broader compatibility is intentionally not claimed.

Demonstrated:

- both browsers already running and logged in
- multiple existing browser windows
- automation foregrounding a background browser
- Chrome using a newly-created normal window without changing profiles
- repeated imports
- Chrome cold launch into the existing profile
- delayed browser bookmark-store persistence
- Safari's delayed success alert
- Safari's password/Touch ID authorization challenge and manual user intervention
- Safari runs beginning with a leftover success or source-deletion prompt
- deterministic nonzero failure when Safari first exposed an unhandled dialog transition

Supported contract:

- unlocked interactive macOS login session
- English (`en-US`) browser UI labels
- tested Safari `26.5` on macOS `26.5.1`
- tested running Chrome `149.0.7827.114`
- no unrelated browser modal dialog
- an available user for Safari interactive authorization

Not demonstrated and therefore not promised:

- locked or logged-out sessions
- non-English browser UI
- future browser menu/accessibility structures
- concurrent user input during automation
- multiple simultaneously active Chrome profiles with ambiguous last-used-profile state
- a fully closed Safari run, although the script activates Safari before invoking its menu
- unattended Safari completion without password/Touch ID interaction

Unrecognized UI, unexpected dialogs, and timeouts must fail nonzero instead of guessing.

## #7: Select A Per-Browser Automation Architecture

Blocked by: #3, #4, #5, #6
Type: Discuss

### Question

Which proven mechanism should Bookmarknot use for Chrome and Safari respectively, and what fallback or explicit unsupported-state behavior is required when their strongest mechanisms differ?

### Answer

Resolved.

- Use AppleScript plus `System Events` as the first implementation for both browsers because it is the only route demonstrated end to end.
- Host it behind a stable Bookmarknot-owned executable boundary with preflight, explicit timeouts, named exit failures, and version telemetry.
- Chrome and Safari share file-panel automation but retain separate browser adapters because their entry and completion contracts differ.
- Chrome completion evidence is successful traversal and file-panel dismissal; store modification time is optional support.
- Safari currently provides assisted automation only: the script drives the browser UI around a password/Touch ID challenge that the user must satisfy, then requires the browser-owned `Import Successful` dialog and the `Not Now` source-retention choice.
- Direct `AXUIElement` automation remains a future hardening option, not the chosen route until it demonstrates a material reliability advantage.
- A later wizard-design decision removed guided handoff from the product contract. Explicit automation failure terminates the run rather than switching modes.

## #8: Prototype Bookmarknot-Owned End-To-End Execution

Blocked by: #7
Type: Prototype

### Question

Can Bookmarknot launch the selected per-browser automation route with the preselected export path, handle permission interruption, receive deterministic exit status, optionally observe bookmark-store modification time, and leave the browser in a usable state?

### Answer

Resolved in the retained SwiftPM executable at `Sources/FullBrowserImportAutomationProbe/main.swift`.

Entrypoints:

- non-mutating preflight: `swift run full-browser-import-automation-probe preflight`
- Chrome live import: `swift run full-browser-import-automation-probe chrome`
- Safari live import: `swift run full-browser-import-automation-probe safari`

The probe:

- owns the fixed preselected input paths
- validates input and installed-browser prerequisites
- launches the per-browser AppleScript through one process boundary
- preserves `osascript` success or failure as process exit status
- records bookmark-store modification time as optional evidence
- follows Chrome's last-used profile when locating its bookmark store
- leaves the source HTML files intact

Both live import commands eventually returned zero. Chrome completed unattended. Safari returned zero only after the user manually satisfied its password/Touch ID challenge, so the Safari probe is not evidence of full automation.

## #9: Revise The Exporter Product Contract

Blocked by: #8
Type: Discuss

### Question

Given demonstrated Chrome and Safari behavior, should `Execute` default to full automation, expose it as an optional mode, or retain the guided handoff for one or both browsers, and what status claims may the UI make?

### Answer

Resolved as the product direction supported by current evidence.

- Full browser import automation is technically feasible for tested Chrome under explicitly granted macOS permissions.
- Tested Safari supports assisted automation, but unattended full automation is not yet demonstrated because Safari required runtime password/Touch ID authorization.
- The later wizard-design decision makes the proven automated route the only import mode: full automation for Chrome and assisted import for Safari.
- The wizard must not offer `Open Guided Import` or silently switch to a guided mode after failure.
- Bookmarknot must not claim success from bookmark content inspection. The accepted success contract is zero automation exit status; bookmark-store modification time is optional supporting evidence.
- Public run states should use `Permission Required`, `Automation Running`, `Authorization Required`, `Automation Completed`, and `Automation Failed` instead of the old user-confirmed guided-handoff states.
- Any missing Accessibility element, permission denial, unexpected dialog, or timeout is `Automation Failed`; it must never be collapsed into success.
- Safari should expose `Authorization Required` while waiting for the user and may state that the browser reported success afterward. Chrome should only state that the automation completed.

The Chrome full-automation path and Safari assisted-automation path are both ready for production planning.

## #10: Characterize Safari Interactive Authorization

Blocked by: #4
Type: Discuss

### Question

What triggers Safari's password/Touch ID challenge during bookmark HTML import, is it required on every run or only under specific security/profile conditions, and does any supported macOS-native mechanism allow it to be authorized before the import without runtime human interaction?

### Answer

Resolved by revising the accepted Safari contract.

- The user permits Safari to pause for password/Touch ID interactive authorization.
- The user satisfies that challenge; Bookmarknot automates every step before and after it.
- The live prototype demonstrated exactly this sequence and then received Safari's `Import Successful` result.
- Whether Safari's challenge is conditional, always required, or avoidable is no longer a blocker for assisted browser import.

## #11: Validate Chrome Bookmarks Bar Cleanup Preflight

Blocked by: #3, #9
Type: Prototype

### Question

Can Bookmarknot's non-mutating preflight validate that Chrome Bookmarks Bar cleanup is possible before a live Chrome import run mutates the active profile?

### Context

Same-file idempotence is a hard browser-side requirement: importing the same final-version bookmark `HTML` into the same target browser profile multiple times must leave the browser bookmark tree unchanged after the first successful import.

Observed browser behavior differs:

- Safari does not create duplicate imports when the same bookmark `HTML` is imported repeatedly.
- Chrome may create repeated `Imported`, `Imported (1)`, `Imported (2)`, and similar folders when importing into a profile that already has bookmarks.

The accepted Chrome import pipeline therefore includes an idempotence cleanup step before import:

- target the currently active Chrome profile/window
- delete all folders and bookmark items visible in Chrome's Bookmarks Bar
- import Bookmarknot's browser-importable bookmark `HTML`, which targets the Bookmarks Bar
- run this cleanup every time before Chrome import; an already-empty Bookmarks Bar is a no-op
- do not delete `Other Bookmarks`, `Mobile Bookmarks`, Reading List, history, saved tabs, or hidden/synced metadata outside the visible Bookmarks Bar
- do not provide backup, rollback, or a second destructive confirmation
- record cleanup attempt/completion in the runtime log

The cleanup mechanism is expected to use the same Chrome UI automation surface proven in ticket `#3`: drive Chrome to a known bookmarks/import state through AppleScript plus `System Events`, rather than directly rewriting Chrome's bookmark store.

### Answer

Resolved in the retained SwiftPM executable at `Sources/FullBrowserImportAutomationProbe/main.swift`.

The non-mutating preflight now validates Chrome Bookmarks Bar cleanup capability before a live Chrome import run:

- it launches Chrome to `chrome://bookmarks/?id=1` in a temporary normal window
- it enables Chrome's enhanced Accessibility tree, as required by ticket `#3`
- it verifies the `Organize` control is reachable
- it verifies the `Bookmarks Bar` row is reachable through keyboard Accessibility focus
- it closes the temporary probe window without invoking delete or import

Live validation returned zero and reported:

- `preflight=passed`
- `chrome-cleanup-preflight=Chrome Bookmarks Bar cleanup surface is reachable`

This does not prove deletion itself, because preflight must remain non-mutating. It proves the browser-owned bookmark-management surface needed by the planned cleanup step is reachable under the same Chrome UI automation constraints as the import probe.
- Unattended Safari import remains unproven and must not be described as full automation.

The resolved automation contract is:

- Chrome: full automation after required macOS permission grants
- Safari: assisted browser import with one explicit password/Touch ID authorization step

## #12: Reuse A Single Chrome Automation Window

Blocked by: #3, #11
Type: Prototype

### Question

Can the Chrome cleanup and import automation comply with the product contract that it must reuse an already-open browser window when available, or open exactly one new window only when no usable normal Chrome window exists?

### Context

Live cleanup demonstrations proved Chrome Bookmarks Bar cleanup is feasible through Chrome's browser-owned bookmark-manager UI, but the ad hoc scripts opened a new Chrome window for each probe or cleanup attempt. That violates the intended automation lifecycle:

- prefer an already-open normal Chrome window in the active logged-in profile
- open one new normal Chrome window only when no usable normal Chrome window is available
- share that same window/tab across Chrome cleanup and import during a single live run
- do not open additional Chrome windows for repeated cleanup loop iterations
- close only windows that Bookmarknot opened itself
- leave user-owned preexisting windows open and usable
- record in the runtime log whether Chrome automation reused an existing window or opened a new one

Preflight may use a temporary Chrome window for its non-mutating capability check, but it must open at most one such window and close it before returning.

### Answer

Resolved in the retained SwiftPM executable.

Chrome window lifecycle is now explicit:

- the live Chrome script selects one normal Chrome window once at the start of the run
- it reuses an existing normal Chrome window when Chrome exposes one
- it opens one normal Chrome window only when no usable normal window exists
- cleanup and import both use the selected window's active tab
- the script returns whether it reused an existing window or opened one
- repeated cleanup/import steps do not open additional windows

The non-mutating Chrome cleanup preflight was also hardened:

- it reuses a normal Chrome window when Chrome exposes one after launch
- it opens at most one normal Chrome window only when no usable window exists
- it closes only a window that the preflight created itself
- it reports whether it reused or opened a window

Verification:

- with Chrome already open, preflight returned zero and preserved the Chrome window count from `5` to `5`
- preflight reported `Chrome Bookmarks Bar cleanup surface is reachable; preflight reused an existing window`
- when Chrome was closed, Chrome itself restored prior session windows on launch; the preflight adopted one restored normal window instead of opening another Bookmarknot-owned window

This resolves the automation contract issue raised by the ad hoc cleanup demonstrations: Bookmarknot must not open a new Chrome window for every cleanup loop or probe step.
