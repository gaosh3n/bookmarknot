# Exporter HTML Format Research

Date: 2026-06-23

## Scope

This note resolves tickets `#2` and `#3` in
[exporter-html-format-and-conversion.md](./exporter-html-format-and-conversion.md).

It distinguishes between:

- official user-facing browser documentation
- current Chromium source that defines Chrome's emitted bookmark export shape
- local validation performed on this Mac

Local environment checked:

- Google Chrome `148.0.7778.181`
- Safari `26.5`

## Chrome

### Official contract

Google documents that Chrome exports bookmarks as an `HTML` file and imports bookmarks from an `HTML` file.

What Google does not publish:

- a normative schema for that `HTML`
- a list of required versus optional tags or attributes

Implication:

- Chrome's public contract is file type and workflow, not a formal specification.

### Source-backed file shape

Chromium's current `bookmark_html_writer.cc` is the strongest primary source for the de facto format Chrome emits.

Current writer behavior:

- file header begins with `<!DOCTYPE NETSCAPE-Bookmark-file-1>`
- file declares UTF-8 via `<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">`
- document title/header use `Bookmarks`
- root container is `<DL><p>`
- the top-level bookmark bar folder is written as `<DT><H3 ... PERSONAL_TOOLBAR_FOLDER="true">Bookmarks bar</H3>`
- folders are written as `<DT><H3 ADD_DATE="..." LAST_MODIFIED="...">Folder Title</H3>`
- folder children are wrapped in nested `<DL><p>` blocks
- bookmarks are written as `<DT><A HREF="..." ADD_DATE="...">Title</A>`
- favicon data may be emitted as optional `ICON="data:image/...;base64,..."`

Chromium's checked-in golden samples confirm the same structure.

### Chrome conclusion

The practical Chrome contract is a de facto Netscape bookmark file with Chromium-specific conventions:

- Netscape bookmark doctype
- nested `DL/DT/H3/A` tree
- UTF-8 meta header
- toolbar folder marker
- timestamp attributes normally present in Chrome-generated files

For Bookmarknot, this means:

- generating a Chromium-shaped Netscape bookmark file is the safest compatibility target
- `ICON` is optional because Bookmarknot does not own favicon bytes
- synthesized timestamps are acceptable if Bookmarknot has no native time data to preserve

## Safari

### Official contract

Apple's current Safari User Guide says Safari can:

- import browsing data from a file or folder
- import bookmarks exported in `HTML` format from Chrome, Edge, Firefox, and some other browsers
- export Safari browsing data to a `.zip` file

Apple's older support note also documents the dedicated bookmark export command:

- `File > Export > Bookmarks`
- default exported filename `Safari Bookmarks.html`

What Apple does not publish:

- a normative bookmark-HTML schema
- a Safari-specific tag or attribute grammar

Implication:

- Safari's public import contract is compatibility with bookmark `HTML` exported by other browsers
- Apple positions bookmark `HTML` as an interchange format, not a Safari-owned structured spec

### Safari conclusion

Safari does not expose a separate documented bookmark-HTML specification.

The strongest evidence is instead:

- Safari explicitly imports bookmark `HTML` exported from Chrome and other browsers
- Safari historically exports `Safari Bookmarks.html`
- current Safari export/import docs describe file-based browser-data interchange, not a distinct Safari bookmark markup

For Bookmarknot, this means:

- targeting the same shared Netscape-style bookmark `HTML` used by Chrome is the best single-file strategy
- there is no source-backed reason to fork into a Safari-only markup variant

## Shared decision

One shared export file should target both browsers.

That file should:

- use the Netscape bookmark doctype
- declare UTF-8 explicitly
- encode the bookmark tree with nested `DL/DT/H3/A`
- include the toolbar-folder marker on the top-level visible folder
- omit unsupported browser-native metadata such as Chrome favicon payloads

## Local validation

Local validation performed in repo:

- implemented a prototype exporter in [BookmarkHTMLExporter.swift](../../Sources/Domain/BookmarkHTMLExporter.swift)
- added tests in [BookmarkHTMLExporterTests.swift](../../Tests/DomainTests/BookmarkHTMLExporterTests.swift)
- ran `swift test`

What this validates:

- Bookmarknot can derive a deterministic Netscape-style export from the canonical JSON tree
- the emitted structure matches the current Chromium writer shape closely enough to serve as the prototype target

What this does not claim:

- a full browser-automation proof that Safari imported a disposable test file on this machine

That stronger claim was intentionally not made because Safari bookmark import mutates the user's real Safari bookmark store, which is not safe to automate in this workspace.

## Sources

- Google Help: https://support.google.com/chrome/answer/96816?hl=en
- Chromium source writer: https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/bookmarks/bookmark_html_writer.cc
- Chromium golden sample: https://chromium.googlesource.com/chromium/src/+/main/chrome/test/data/bookmark_html_writer/bookmarks_in_bookmarks_bar.html
- Apple Safari User Guide, import from file or folder: https://support.apple.com/en-sa/guide/safari/ibrw9ffa6d10/mac
- Apple Safari User Guide, export browsing data: https://support.apple.com/en-vn/guide/safari/ibrwebf10132/mac
- Apple Support, dedicated bookmark export: https://support.apple.com/en-us/117827
