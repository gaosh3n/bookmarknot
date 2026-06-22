## #1: Define The Export Artifact Boundary

Blocked by: none
Type: Discuss

### Question

What exactly is the artifact this investigation is trying to define: a browser-native bookmark database, a Bookmarknot storage replacement, or a derived browser-importable export?

### Answer

Resolved from ADR 0002 and the existing exporter notes:

- Bookmarknot's durable artifact remains the canonical JSON tree defined in [0002-define-mvp-artifact-format.md](../adr/0002-define-mvp-artifact-format.md).
- This exploration is about a separate derived artifact: browser-importable bookmark export `HTML`.
- The derived `HTML` only needs to preserve the bookmark tree meaning that Bookmarknot already owns: folder titles, bookmark titles, and bookmark URLs.
- Browser-native metadata, sync fields, and full round-trip fidelity remain out of scope unless later research proves they are required for import correctness.

Settled implication for downstream tickets:

- research should focus on import-compatibility requirements for `HTML`, not on replacing the canonical JSON format
- conversion design should start from Bookmarknot's canonical tree, not from Chrome's or Safari's full native storage models

## #2: Research Chrome's Bookmark HTML Contract

Blocked by: #1
Type: Research

### Question

Does Chrome define a formal bookmark-import `HTML` specification, or is the real contract a de facto Netscape-style bookmark file shape? Which fields and structure are required, tolerated, or ignored by current Chrome import?

### Answer

Resolved in [exporter-html-format-research.md](./exporter-html-format-research.md).

- Google documents bookmark import and export as `HTML`, but does not publish a normative schema or required-field list.
- Chromium's current writer and checked-in golden sample define the strongest practical contract: Netscape bookmark doctype, an explicit UTF-8 meta declaration, and a nested `DL/DT/H3/A` tree.
- Chrome-generated files add `ADD_DATE` and `LAST_MODIFIED` timestamps, mark the bookmark-bar folder with `PERSONAL_TOOLBAR_FOLDER="true"`, and may include favicon data in `ICON`.
- Bookmarknot should follow that Chromium-shaped structure, synthesize timestamps because its canonical artifact has none, and omit favicon data because it does not own those bytes.

Decision: Chrome's bookmark `HTML` is a de facto Netscape-style interchange format, not a separately published Google specification.

## #3: Research Safari's Bookmark HTML/File Import Contract

Blocked by: #1
Type: Research

### Question

Does Safari define a bookmark-specific `HTML` specification for `File > Import Browsing Data from File or Folder`, or does it accept the same de facto bookmark-export `HTML` shape as Chrome? Which parts of the file appear required for current Safari import?

### Answer

Resolved in [exporter-html-format-research.md](./exporter-html-format-research.md).

- Apple documents importing bookmarks exported in `HTML` format by Chrome and other browsers.
- Apple has also documented Safari's dedicated bookmark export with the default filename `Safari Bookmarks.html`.
- Apple does not publish a Safari-specific bookmark-markup schema or required-field grammar.

Decision: Safari treats bookmark `HTML` as a documented interchange input, but the markup itself is the shared de facto browser format. There is no evidence that Bookmarknot needs a Safari-only variant.

## #4: Define The Canonical-JSON To Export-HTML Mapping

Blocked by: #2, #3
Type: Discuss

### Question

Given Bookmarknot's canonical JSON tree, what exact `HTML` structure should Bookmarknot emit so one export can target both Chrome and Safari if possible?

### Answer

Resolved as one shared Chrome-and-Safari export mapping:

- Emit `<!DOCTYPE NETSCAPE-Bookmark-file-1>`, an explicit UTF-8 meta declaration, `Bookmarks` title/header elements, and a root `<DL><p>` container.
- Map Bookmarknot's anonymous canonical root to a visible top-level `Bookmarks bar` folder marked with `PERSONAL_TOOLBAR_FOLDER="true"`. This retains every canonical child while giving browser importers the conventional toolbar container they expect.
- Map each folder to `<DT><H3 ADD_DATE="0" LAST_MODIFIED="0">title</H3>` followed by a nested `<DL><p>` containing its children.
- Map each leaf to `<DT><A HREF="url" ADD_DATE="0">title</A>`.
- HTML-escape folder titles, bookmark titles, and URL attribute values.
- Synthesize unavailable timestamps as `0`; omit favicon `ICON` data and all other browser-native metadata outside Bookmarknot's canonical tree.
- Encode as UTF-8 and use CRLF line endings for deterministic Chromium-shaped output.

The concrete mapping is implemented by [BookmarkHTMLExporter.swift](../../Sources/Domain/BookmarkHTMLExporter.swift).

## #5: Prototype And Validate A Minimal Serializer

Blocked by: #4
Type: Prototype

### Question

Can Bookmarknot generate a minimal export `HTML` file from the canonical JSON tree that both target browsers actually accept during import on a current macOS setup?

### Answer

Resolved by implementing the serializer in [BookmarkHTMLExporter.swift](../../Sources/Domain/BookmarkHTMLExporter.swift) and executable examples/assertions in [BookmarkHTMLExporterTests.swift](../../Tests/DomainTests/BookmarkHTMLExporterTests.swift).

The prototype established that Bookmarknot can deterministically derive the agreed Netscape-style file from a canonical tree, including nested folders, links, escaping, the toolbar marker, synthesized timestamps, UTF-8, and CRLF output. The validated behavior was absorbed into the Domain module instead of retaining throwaway prototype code.

Validation result:

- `swift test` passes with generated-output coverage for the shared structure and escaping behavior.
- The emitted shape is checked against Chromium's current writer and golden sample, providing source-backed Chrome compatibility evidence.
- Safari officially accepts Chrome-exported bookmark `HTML`, providing documentation-backed evidence for the shared format.
- Direct Safari import automation was not performed because it would mutate the user's real Safari bookmark store. Therefore this resolution establishes the serializer and compatibility target, but does not claim a destructive end-to-end Safari import test.

No further format-decision tickets remain. Browser UI integration and user-facing export workflow belong to implementation planning outside this map.
