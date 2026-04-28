# 3. Define bookmarknot MVP UI flow

Date: 2026-06-05

## Status

Accepted

## Context

Bookmarknot needs an MVP macOS UI for generating app-owned bookmark artifacts from Google Chrome and Safari bookmark sources.

ADR 0002 defines the MVP artifact format, browser import rules, merge roles, decision model, and MVP non-goals. This decision records the user-facing flow around those artifact rules. It does not revise the artifact format.

The UI must support:

- Viewing discovered Google Chrome and Safari bookmark artifacts as source rows.
- Viewing local Bookmarknot artifacts.
- Manually refreshing each artifact list.
- Generating a new Bookmarknot artifact through a wizard that lets the user review and resolve decisions.
- Showing runtime errors without exposing technical detail in pop-up dialogs.

## Decision

Bookmarknot MVP will be a native, non-sandboxed SwiftUI macOS app.

The app will use a single main window. The sidebar contains two items:

- `Configuration`
- `Runtime Log`

The app opens to `Configuration`. No artifact list refreshes automatically on launch. Lists start in a not-refreshed state.

The `Configuration` panel contains three vertically separated, resizable sections:

- `Chrome Artifacts`
- `Safari Artifacts`
- `Bookmarknot Artifacts`

Each section has a fixed header. The three `Refresh` buttons are visually aligned. In the `Bookmarknot Artifacts` section, `Generate` is placed to the right of `Refresh`.

Each `Refresh` button has a tip icon with the tooltip:

```text
Refresh the list if it is empty now.
```

`Generate` is always visible. When disabled, it also has a tip icon with the same tooltip.

### Configuration Tables

Each artifact section displays rows in a multi-column list rather than a separate detail strip.

Columns are configurable per section. Users can toggle optional columns on or off. Column visibility preferences persist across app launches. Section heights and column widths also persist across app launches.

The column that identifies the artifact row cannot be hidden:

- Google Chrome and Safari use `Path`.
- Bookmarknot uses `Short Hash`.

Rows are sorted by artifact creation time descending. Rows are not user-sortable in the MVP.

Default selection after refresh:

- Select the newest successful artifact row.
- If there are no successful rows but failed rows exist, select the newest failed row for display.
- If there are no rows, select nothing.

The source sections display user-friendly metadata such as path, creation time, bookmark count, folder count, file size, and status when available. The Bookmarknot section displays user-friendly metadata such as short hash, creation time, bookmark count, folder count, and file size. Full SHA-256 hashes and full local artifact paths are not shown by default.

### Source Refresh

`Chrome` means Google Chrome only. Other Chromium-family browsers are out of scope for the MVP.

`Safari` means Safari's native bookmarks plist only. Exported Safari HTML import and custom import paths are out of scope for the MVP.

Google Chrome and Safari source refreshes are manual. When a source section is refreshed, the app discovers browser-native artifacts, parses them, converts them into Bookmarknot-designed artifacts, and writes converted source artifacts under:

```text
~/Library/Application Support/Bookmarknot/sources/Chrome/
~/Library/Application Support/Bookmarknot/sources/Safari/
```

Each source directory has an `index.json` for source metadata and converted artifact filenames. Converted source artifacts are not stored inside the immutable Bookmarknot artifact directory.

Each source refresh regenerates that source directory from the latest refresh result. Refresh writes into a temporary directory and swaps the directory after all discovered artifacts have finished processing. If at least one artifact succeeds, the swapped directory contains converted artifacts for successful rows and index metadata for both successful and failed display rows. If every discovered artifact fails, the displayed list is empty after the error dialog.

For Google Chrome, multiple profile artifacts may be discovered. Profile parsing and conversion may proceed concurrently, and all attempts must finish with either success or failure before the refresh result is shown.

Refresh result display:

- If every discovered artifact succeeds, show all successful rows with no warning.
- If some artifacts succeed and some fail, show successful and failed rows. Failed rows have a warning icon at the end of the row.
- If every discovered artifact fails, show the dialog `Cannot load artifacts. See Runtime Log.`, then show an empty list.
- Runtime Log records all refresh errors and exceptions.

Failed rows are selectable for display. They can show available details such as path, creation time, and file size. Failed rows cannot be used for generation.

Successful source rows can be used for generation. If Google Chrome has multiple rows, the selected successful Chrome row is the Chrome source. A failed selected Chrome row means Chrome does not participate in generation. Safari has at most one source artifact in the MVP and is selected automatically when successfully loaded.

### Bookmarknot Artifact Refresh

The Bookmarknot section refresh is manual. It handles only Bookmarknot-owned local artifact state.

On refresh, the app ensures the Bookmarknot artifact directory exists, validates it, and displays valid local artifacts sorted by creation time descending. An empty valid artifact directory is a valid state.

If the Bookmarknot artifact directory cannot be created, read, or validated, the app shows:

```text
Cannot load artifacts. See Runtime Log.
```

The app logs details, clears the Bookmarknot artifact list, and disables `Generate`. The app does not keep showing an older local artifact list after local refresh failure.

### Generate Enablement

`Generate` is enabled only when:

- The Bookmarknot section has been refreshed successfully and the local artifact directory is valid.
- At least one successful selected source artifact is available from Google Chrome or Safari.

If both Safari and a selected successful Google Chrome artifact are available, generation uses both sources. Safari is current and Google Chrome is incoming, as defined in ADR 0002.

If only one successful source is available, generation uses that one source and still opens the generation wizard.

`Generate` uses the converted source artifacts from the latest successful source refresh, not a new read of the browser-native files.

### Generation Wizard

Clicking `Generate` opens a modal sheet attached to the main window. The main window remains visible but inactive behind the sheet. The MVP supports only one main window.

The generation wizard is only for review and decision resolution. It does not show a source summary step, selected source paths, or artifact storage details.

The wizard always has:

- `Done`
- `Cancel`

`Done` is disabled until all required decisions are resolved. Saving only happens when the user explicitly clicks `Done`.

`Cancel` always shows an abort confirmation:

```text
Abort generation? Unresolved progress will be lost and no artifact will be saved.
```

Confirming abort closes the wizard, discards progress, and saves nothing. Declining abort returns to the wizard.

Generation operates on a frozen session created from the selected converted source artifacts at the time `Generate` is clicked. Source changes on disk after that point do not affect the open wizard.

The wizard uses a Git merge/conflict style:

- Safari/current candidates are red.
- Google Chrome/incoming candidates are green.
- Decision controls are always `Accept` and `Reject`.
- Users can resolve high-level collapsed items or unfold descendants and resolve them one by one.
- Hidden descendants remain accessible by unfolding.
- No separate visual style distinguishes inherited and directly clicked decisions.
- No search or filter controls are included in the MVP.

For one-source generation, the same review-and-resolve wizard model applies. The source tree can be accepted or rejected at higher levels, and users may unfold descendants and resolve them one by one. If the only source is fully rejected, no artifact can be saved.

### Save Outcomes

When `Done` creates a new Bookmarknot artifact successfully:

- The wizard closes.
- No success dialog is shown.
- The Bookmarknot section updates immediately.
- The generated artifact row is selected.

When `Done` computes an artifact hash that already exists as a valid local artifact:

- The app shows an informational dialog:

```text
No change in artifact.
```

- The wizard closes.
- The existing artifact row is selected.
- The app does not modify or overwrite the existing artifact.

If generation fails before or during the wizard flow, the app shows:

```text
Generation aborted. See Runtime Log.
```

The app logs details, aborts generation, closes the wizard if it is open, and saves no artifact.

### Runtime Log

The `Runtime Log` sidebar item shows runtime log content as read-only text. It updates live as runtime errors and exceptions occur.

Runtime logs are stored under:

```text
~/Library/Application Support/Bookmarknot/logs/
```

The MVP uses a single visible runtime log concept. Logging implementation details are out of scope for this decision.

The Runtime Log panel has a `Clean` button. `Clean` immediately truncates log content and refreshes the visible panel to empty. The app does not delete the log file.

Pop-up dialogs do not include technical detail. Details belong in Runtime Log.

## Consequences

The MVP has a focused two-panel navigation model instead of separate sidebar panels for each artifact source.

Manual refresh makes artifact discovery explicit and avoids hidden filesystem scanning on launch.

Converted source caches make generation stable after refresh and separate browser-source state from immutable Bookmarknot artifacts.

The generation wizard remains narrowly scoped to review and resolution, which keeps import readiness, source display, and local artifact management out of the wizard.

The UI supports partial source-refresh success without blocking valid converted source artifacts.

The MVP intentionally excludes automatic browser watching, browser-open warnings, custom imports, exported Safari HTML import, browser write-back, commit messages, revert/reset, artifact comparison, search, filters, and advanced logging controls.
