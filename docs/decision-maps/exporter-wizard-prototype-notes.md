# Exporter Automated Import Wizard Prototype Notes

Date: 2026-06-24

Question:

What revised stepwise attached-sheet design makes browser selection, explicit start, permission recovery, active automation, Safari authorization, completion, and fatal failure clear without becoming an operator console?

Prototype:

- throwaway SwiftUI surface across `Sources/UI/ExporterWizardPrototype*.swift`
- run with `swift run bookmarknot --prototype-exporter-wizard`
- three structurally different variants:
  - `A` `Guided Rail`
  - `B` `Journey`
  - `C` `Focused Sheet`
- a separate `PROTOTYPE` scenario bar simulates preflight, permission, automation, authorization, success, and failure without presenting those controls as production actions

Validated lifecycle:

- one shared selected export remains visible and does not change with browser choice
- `Start Import` is explicit and runs preflight before browser mutation
- missing macOS permission pauses at `Permission Required` until the user chooses `Check Again`
- active automation exposes no close or cancel action
- Safari's browser-owned Touch ID/password dialog maps to a passive `Authorization Required` wait and resumes without ending the wizard
- success ends at `Import Completed` with only `Close`
- runtime failure opens an acknowledgment dialog directing the user to Runtime Log; acknowledgment closes the wizard
- guided handoff and user-reported `Imported`, `Failed`, or `Unknown` outcomes are absent

Chosen direction:

- Use variant `A`, `Guided Rail`, as the durable structure.
- After user review, align variant `A` with the existing Configuration Importer wizard's default macOS system typography; do not use rounded display fonts.
- Keep a persistent four-step rail: `Review`, `Permissions`, `Import`, `Finish`.
- Render only the current step's controls in the main content area.
- Keep the compact status badge and selected export summary.
- Use browser-specific copy only where behavior actually differs: Chrome is fully automated; Safari may require interactive authorization.
- Keep detailed execution trace in Runtime Log rather than duplicating it in the wizard.

Why `A` wins:

- The rail makes permission setup and Safari authorization read as parts of one uninterrupted run.
- It communicates progress more clearly than variant `C` without the persistent two-panel density of variant `B`.
- It remains consistent with the app's existing attached-sheet wizard direction.

Validation:

- `swift build` compiled the revised prototype.
- `xcodebuildmcp macos build-and-run --project-path bookmarknot.xcodeproj --scheme bookmarknot --launch-args --prototype-exporter-wizard` built and launched the native app.
- Accessibility-tree interaction traversed permission pause, fatal-error acknowledgment and closure, Safari authorization, automatic continuation, and completion across all three variants at the app's `960 x 720` window size.
- Screen capture was unavailable in the validation environment.

Durable answer:

Use an attached-sheet wizard based on `Guided Rail`. The production surface has four stages and no guided fallback: review the shared export and browser, preflight permissions, run full or assisted automation without cancellation, then show deterministic completion or terminate through the Runtime Log error dialog.
