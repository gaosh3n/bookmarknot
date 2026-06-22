## #1: Define The Exporter Interaction Boundary

Blocked by: none
Type: Discuss

### Question

After the user clicks the single `Execute` action in `Exporter`, what category of interaction is Bookmarknot designing?

### Answer

Resolved and revised after browser automation was proven.

- `Execute` opens an app-owned attached-sheet wizard for the selected export row.
- Bookmarknot drives Chrome's browser-owned import flow fully after required macOS permissions are granted.
- Bookmarknot drives Safari's flow except for one permitted password/Touch ID interactive authorization.
- Guided handoff is not a product fallback.
- Export preparation remains separate: `Refresh` generates or rediscovers export rows; `Execute` consumes the selected row.

## #2: Establish Browser Automation Capability

Blocked by: #1
Type: Research

### Question

What can Bookmarknot automate and observe for Chrome and Safari on macOS?

### Answer

Resolved by [exporter-full-browser-import-automation.md](./exporter-full-browser-import-automation.md).

- Chrome supports proven full browser import automation in the tested environment.
- Safari supports proven assisted browser import with one browser-owned interactive authorization step.
- Both use browser-owned import UI driven through AppleScript and `System Events` behind a stable Bookmarknot-owned process boundary.
- A zero automation exit status is completion evidence; Safari additionally exposes its browser-owned success dialog.
- Unexpected UI, denied access, timeouts, and nonzero exits are failures rather than unknown outcomes.

## #3: Define The Automated Status Model

Blocked by: #1, #2
Type: Discuss

### Question

What states may the exporter wizard show while remaining honest about the automated run?

### Answer

Resolved.

- `Ready`: browser and selected shared export are reviewable; `Start Import` is available.
- `Checking Permissions`: non-mutating preflight is running.
- `Permission Required`: the wizard waits without polling until the user grants access and chooses `Check Again`.
- `Importing`: browser automation is active; closing and cancellation are unavailable.
- `Authorization Required`: Safari is presenting password/Touch ID; Bookmarknot waits passively and resumes automatically.
- `Import Completed`: automation completed successfully; the selected browser and export remain visible and `Close` is the only action.
- Runtime failure is not a persistent wizard state. It aborts the run and opens an acknowledgment dialog directing the user to Runtime Log; acknowledgment closes the wizard.

There are no user-reported success, failure, cancellation, or unknown outcomes.

## #4: Decide Export HTML Freshness And Lifetime

Blocked by: #1
Type: Discuss

### Question

When is browser-importable `HTML` generated and how is staleness handled?

### Answer

Resolved.

- `Exporter` has one shared selection list of `HTML` exports derived from Bookmarknot artifacts.
- `Refresh` writes, updates, or rediscovers those files under app-owned support storage.
- Each row identifies one concrete export file and corresponds to one Bookmarknot artifact.
- `Execute` uses the selected row without silently regenerating it.
- A later refresh may replace the prior derived file for the same artifact; unrepresented old exports may be cleaned up opportunistically.

## #5: Prototype The Automated Import Wizard

Blocked by: #1, #3, #4
Type: Prototype

### Question

What wizard structure makes the automated lifecycle clear without becoming an operator console?

### Answer

Resolved in [exporter-wizard-prototype-notes.md](./exporter-wizard-prototype-notes.md).

- Use variant `A`, `Guided Rail`, as the production direction.
- Keep four persistent steps: `Review`, `Permissions`, `Import`, `Finish`.
- Show only the current step's controls in the main area.
- Keep the selected shared export, target browser, compact status, and browser-specific expectation visible where relevant.
- Keep execution trace in Runtime Log.

## #6: Define The Execute Contract

Blocked by: #2, #3, #5
Type: Discuss

### Question

What exactly does the single `Execute` action do?

### Answer

Resolved.

1. Read the selected shared export row and open the attached-sheet wizard.
2. Show the selected export and preselected browser; allow browser choice before the run.
3. Wait for the explicit `Start Import` action.
4. Run preflight. If permission is missing, remain at `Permission Required` until `Check Again` succeeds.
5. Start the selected browser adapter and prevent wizard closure or cancellation.
6. For Chrome, automate through completion. For Safari, passively wait during password/Touch ID and resume afterward.
7. On success, show `Import Completed` until `Close`.
8. On failure, abort and show the Runtime Log acknowledgment dialog; acknowledgment closes the wizard.

## #7: Decide Exporter Copy And Control Labels

Blocked by: #3, #5, #6
Type: Discuss

### Question

Should the panel control remain labeled `Execute`?

### Answer

Resolved as current wording.

- Keep `Execute` on the `Exporter` panel because it opens the multi-stage browser-import operation.
- Use the more specific `Start Import` inside the wizard once the export and target browser are visible.
