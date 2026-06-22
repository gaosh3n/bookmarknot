# Exporter Automated Import Wizard

This map redesigns the existing exporter wizard around the proven Chrome full-automation and Safari assisted-import routes. The shared export list, single `Refresh`, single `Execute`, and browser selection inside the wizard remain settled.

## PRD-Critical Acceptance Criterion: Same-File Idempotence

> Importing the same final-version bookmark `HTML` file into the same target browser profile multiple times must leave the browser bookmark tree unchanged after the first successful import. This is a production import-contract requirement, not a responsibility of the wizard prototype. A future PRD must preserve it as a hard acceptance criterion.

The wizard should not add duplicate warnings, import receipts, an `Already Imported` result, or other speculative UI unless the production implementation requires them.

## #1: Rebase The Wizard On Automated Import

Blocked by: none
Type: Discuss

### Question

Which parts of the guided-handoff wizard contract survive now that Chrome full automation and Safari assisted import are proven feasible?

### Answer

Resolved through grilling.

- Keep one shared export selection list, one `Refresh`, and one `Execute` in the `Exporter` panel.
- `Execute` opens an app-owned attached-sheet wizard for the selected export.
- Keep browser choice inside the wizard, using the settled prototype preselection.
- Show the selected export and a separate `Start Import` action before automation begins.
- Chrome uses full browser import automation after required macOS permissions are granted.
- Safari uses assisted browser import and permits one password/Touch ID interactive authorization step.
- Remove guided handoff and `Open Guided Import` from the product contract entirely.
- The wizard must not ask the user to report `Imported`, `Failed`, or `Unknown` outcomes.

## #2: Define The Automated Run Lifecycle

Blocked by: #1
Type: Discuss

### Question

What states and interruption rules must the redesigned wizard expose during preflight, automation, Safari authorization, success, and failure?

### Answer

Resolved through grilling and the completed automation map.

- Starting import runs non-mutating preflight for the chosen browser and selected export.
- Missing Automation or Accessibility permission leaves the wizard open in `Permission Required`; Bookmarknot waits without polling, and the user explicitly chooses `Check Again` after changing System Settings.
- Once browser automation starts, wizard closing and cancellation are disabled until success or detected runtime failure.
- Chrome proceeds without further interaction after permission grant.
- When Safari presents password/Touch ID, show `Authorization Required`; Bookmarknot waits passively while the browser-owned dialog is present and resumes automatically after the user satisfies it.
- The Safari authorization dialog is part of the uninterrupted run and must not terminate the wizard.
- Success leaves the wizard open on `Import Completed`, showing the target browser and selected export; `Close` is the only action.
- Runtime failure aborts the run and presents an acknowledgment dialog directing the user to Runtime Log. Acknowledging the dialog closes both it and the wizard.
- There is no retry or alternate import path inside a failed wizard run. A later attempt begins with a new `Execute` run.

## #3: Preserve Import Idempotence In The Production Contract

Blocked by: #1
Type: Discuss

### Question

How should same-file idempotence affect the wizard redesign and future production planning?

### Answer

Resolved through grilling.

- Same-file idempotence is mandatory for the production browser-import operation.
- It means later imports of the same final-version `HTML` into the same target browser profile leave the browser bookmark tree unchanged, including no duplicate bookmarks or duplicate import folders.
- Importing a different preselected final-version `HTML` may intentionally override prior bookmark content.
- Proving or implementing idempotence is outside the throwaway wizard prototype's responsibility.
- The wizard presents repeated successful executions normally and does not speculate about the eventual implementation mechanism.
- The future exporter PRD must state this requirement prominently as a hard acceptance criterion.

## #4: Prototype The Automated Import Wizard

Blocked by: #1, #2
Type: Prototype

### Question

What revised stepwise attached-sheet design makes browser selection, explicit start, permission recovery, active automation, Safari authorization, completion, and fatal failure clear without becoming an operator console?

### Answer

Resolved in [exporter-wizard-prototype-notes.md](./exporter-wizard-prototype-notes.md).

- Revised the existing throwaway SwiftUI prototype while retaining its one-command launch surface.
- Compared `A` `Guided Rail`, `B` `Journey`, and `C` `Focused Sheet`.
- All variants simulate one shared export, explicit start, non-mutating preflight, permission recovery, locked active automation, Safari authorization standby, deterministic completion, and fatal-error closure.
- Guided-handoff instructions and user-reported outcomes were removed.
- Variant `A` best communicates one uninterrupted wizard without dashboard density.

## #5: Select The Durable Wizard Interaction Contract

Blocked by: #4
Type: Discuss

### Question

Which prototype structure should become the production interaction contract, and what exact controls, status copy, and browser-specific distinctions should survive after the prototype is deleted?

### Answer

Resolved from the prototype evidence.

- Use `Guided Rail` as the durable attached-sheet structure.
- Use the existing Configuration Importer wizard's default macOS system typography rather than rounded display fonts.
- Keep four stages: `Review`, `Permissions`, `Import`, `Finish`.
- Show only the current stage's controls while the rail preserves orientation.
- Use `Start Import`, `Check Again`, and terminal `Close` as the principal user actions.
- Active automation and Safari authorization expose no close or cancel action.
- Chrome copy says full automation; Safari copy explains that Touch ID or password may be required and that Bookmarknot continues automatically.
- Runtime failure uses the agreed acknowledgment dialog and Runtime Log boundary, then closes the wizard.
- Updated [exporter-how-to-interact.md](./exporter-how-to-interact.md) and the durable prototype notes to remove the old guided-handoff model.

## #6: Establish PRD Readiness

Blocked by: #3, #5
Type: Discuss

### Question

Is the redesigned wizard contract complete enough for a future exporter PRD, including its production idempotence gate, or has the prototype exposed another decision that must be resolved first?

### Answer

Resolved. The redesigned interaction contract is ready to feed a future exporter PRD.

- The wizard lifecycle, browser-specific behavior, controls, success ending, and failure ending are settled.
- The prototype exposed no additional interaction decision requiring another ticket.
- Same-file import idempotence remains a hard production acceptance criterion and must be prominent in the PRD.
- The implementation mechanism for idempotence is intentionally not selected by this UI decision map.

The decision map is complete.
