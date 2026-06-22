# Exporter Browser Handoff Capabilities On macOS

Date: 2026-06-22

> Historical research note: the guided-handoff product conclusion in this document was superseded after [full and assisted browser import automation](./exporter-full-browser-import-automation.md) was proven. The current wizard contract is recorded in [exporter-automated-import-wizard.md](./exporter-automated-import-wizard.md).

## Scope

This note answers ticket `#2` in `docs/decision-maps/exporter-how-to-interact.md`.

It distinguishes between:

- officially documented browser import paths
- locally inspected AppleScript/scriptability surface on this Mac
- automation techniques that are technically possible but weak as a product contract

Local inspection used:

- Safari `26.5`
- Google Chrome `149.0.7827.115`
- each app's scripting dictionary via `sdef`

## Official Browser Import Paths

### Safari

Apple documents two import paths:

- `File > Import From Browser > Google Chrome` or `Firefox`
- `File > Import Browsing Data from File or Folder`

The second path explicitly supports importing a file or folder chosen by the user, and bookmarks are one of the supported data types.

Implication for Bookmarknot:

- Safari has an official file-based import story that matches Bookmarknot generating export HTML.
- The file choice occurs inside Safari's own import UI.

### Chrome

Google documents bookmark import from an exported HTML file:

- open Chrome
- open `Bookmarks and lists`
- choose `Import bookmarks and settings`
- choose the file

Google also documents the Bookmark Manager path:

- open Bookmark Manager
- choose `Import Bookmarks from HTML file`

Implication for Bookmarknot:

- Chrome has an official HTML import story for Bookmarknot-generated export HTML.
- The file choice occurs inside Chrome's own import UI.

## Scriptability And Automation Surface

### Safari

Safari's scripting dictionary exposes window/tab control, JavaScript execution, and `show bookmarks`.

What it does not expose:

- a bookmark-import AppleScript command
- a file-import AppleScript command for bookmarks
- an observable "bookmark import finished" command or event

Conclusion:

- Bookmarknot can launch Safari and bring the user near bookmark-related UI.
- Bookmarknot cannot rely on a first-class Safari scripting API to perform bookmark import or confirm completion.

### Chrome

Chrome's scripting dictionary exposes windows, tabs, JavaScript execution, and direct access to bookmark objects.

What it does not expose:

- an HTML bookmark-import AppleScript command
- an official scripting command to invoke the import flow
- an observable "bookmark import finished" command or event

Conclusion:

- Bookmarknot can launch Chrome and control generic tab/window behavior.
- Bookmarknot cannot rely on a first-class Chrome scripting API to perform HTML bookmark import or confirm completion.

## File Picker Ownership

For both browsers, the documented import flow ends in browser-owned file-selection UI.

Practical consequence:

- Bookmarknot can prepare the export file and tell the user exactly which file to choose.
- Bookmarknot cannot honestly claim that the file picker stayed app-owned once the browser import step begins.

## What Bookmarknot Can Reliably Observe

Bookmarknot can reliably observe:

- whether it generated or refreshed the export HTML
- the export file path it asked the user to use
- whether it launched Safari or Chrome
- whether AppleScript/launch requests failed before the browser-side step

Bookmarknot cannot reliably observe, from the reviewed official/scriptable surfaces alone:

- that the user selected the intended file
- that the browser accepted the file
- that the browser merged/imported the bookmarks successfully
- that the import changed the browser's bookmark model as intended

This means the post-launch phase is user-confirmed or unknown, not app-confirmed.

## Technically Possible But Weak Product Contracts

Two automation families exist, but both are poor as a primary product contract.

### Apple Events / AppleScript

Apple's automation documentation makes clear that inter-app Apple events are permission-sensitive, and sandboxed apps may need scripting-target or temporary exception entitlements.

Even aside from entitlement/distribution concerns, the inspected Safari and Chrome dictionaries do not expose the import commands Bookmarknot would need.

So Apple events are useful for:

- launching the browser
- focusing windows or tabs
- possibly opening a nearby page or UI surface

They are not enough for a trustworthy cross-browser import contract.

### Accessibility / UI automation

macOS accessibility APIs can be permission-gated via `AXIsProcessTrustedWithOptions`.

This makes menu-click and dialog-driving automation technically possible in principle, but that would depend on:

- accessibility permission
- fragile UI labels and menu structure
- browser version stability
- timing-sensitive UI automation

Conclusion:

- Accessibility automation is better treated as an implementation experiment or optional assist, not the core MVP contract.

## Decision Impact

The safest contract for Bookmarknot is:

- app-owned wizard sheet as the primary UX
- Bookmarknot prepares the export HTML
- Bookmarknot may launch the target browser and point the user to the relevant import step
- the actual browser import remains a guided handoff
- final completion is either user-confirmed or unknown

## Sources

- Google Help: https://support.google.com/chrome/answer/96816?hl=en
- Apple Support: https://support.apple.com/guide/safari/import-bookmarks-and-passwords-ibrw1015/mac
- Apple Support: https://support.apple.com/en-sa/guide/safari/ibrw9ffa6d10/mac
- Apple Developer: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events
- Apple Developer archive QA1888: https://developer.apple.com/library/archive/qa/qa1888/_index.html
- Apple Developer: https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions
