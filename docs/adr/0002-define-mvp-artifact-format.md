# 2. Define bookmarknot MVP artifact format

Date: 2026-06-04

## Status

Accepted

## Context

Bookmarknot needs an MVP storage format for merged bookmarks from Safari and Chrome.

The browser-native bookmark artifacts are structurally different:

- Chrome stores bookmarks as JSON under `roots.bookmark_bar`, `roots.other`, and `roots.synced`, with `folder` and `url` nodes.
- Safari stores bookmarks as a property-list tree using node types such as `WebBookmarkTypeList`, `WebBookmarkTypeLeaf`, and `WebBookmarkTypeProxy`.

The MVP needs a canonical artifact that supports deterministic comparison, merge review, immutable saved states, and human-readable diffs. The artifact should not preserve full browser-native metadata or become a general browser bookmark store.

## Decision

Bookmarknot MVP will use a reduced Safari-like JSON tree as its canonical artifact.

The artifact file contains only the root tree. It has no metadata wrapper, schema version, source browser metadata, merge log, import log, conflict section, or browser-native sync fields.

The root node is an anonymous list:

```json
{
  "WebBookmarkType": "WebBookmarkTypeList",
  "WebBookmarkUUID": "md5-of-root",
  "Title": "",
  "Children": []
}
```

List nodes use this key order:

```json
{
  "WebBookmarkType": "WebBookmarkTypeList",
  "WebBookmarkUUID": "md5-of-folder-path",
  "Title": "Folder title",
  "Children": []
}
```

Leaf nodes use this key order:

```json
{
  "WebBookmarkType": "WebBookmarkTypeLeaf",
  "WebBookmarkUUID": "md5-of-url",
  "URLString": "https://example.com",
  "URIDictionary": {
    "title": "Bookmark title"
  }
}
```

Canonical JSON serialization uses:

- UTF-8 JSON with Unicode characters preserved directly.
- Two-space indentation.
- LF line endings.
- Domain-specific key order as shown above.

Artifact files are immutable and content-addressed:

- Filename: `<sha256-of-canonical-json>.json`
- Artifact directory for MVP: `~/Library/Application Support/Bookmarknot/artifacts/`
- During development, local artifacts may be kept under `.tmp/bookmarknot-artifacts/`.

The app ensures the artifact directory exists. An empty artifact directory is valid. A non-empty artifact directory is valid only if every entry is a valid artifact file and each filename hash matches its canonical JSON bytes. Non-artifact files and subdirectories make the directory invalid.

Node identity is deterministic:

- Root UUID: `md5("folder:")`
- Folder UUID: `md5("folder:" + normalizedFolderPathSegments.join("\x1F"))`
- Leaf UUID: `md5("leaf:" + minimallyNormalizedURLString)`

Folder path normalization uses Unicode NFC, Unicode case folding, and locale-independent comparison. The stored `Title` remains browser-provided text, except empty or whitespace-only folder titles fail import.

Leaf URL identity uses minimal URL normalization only for identity:

- Lowercase recognizable scheme.
- Lowercase recognizable host.
- Remove default port `:80` for `http` and `:443` for `https`.
- Preserve path, query, fragment, and trailing slash.
- Do not strip tracking parameters.
- Do not decode or re-encode path or query.
- If the URL string cannot be normalized this way, use the original `URLString`.

Bookmarknot does not validate URLs beyond requiring `URLString` to be a non-empty string. Empty or whitespace-only leaf titles are stored as the leaf `URLString`.

Children are stored in canonical order:

1. `WebBookmarkTypeList` nodes before `WebBookmarkTypeLeaf` nodes.
2. Within each group, sort by display title using Unicode NFC, Unicode case folding, and locale-independent comparison.
3. For leaf title ties, sort by `URLString` using the same normalization for comparison.
4. For remaining ties, sort by `WebBookmarkUUID`.

Duplicate policy:

- No duplicate URLs are allowed in canonical artifacts.
- Duplicate leaf URL identity is based on the leaf UUID rule.
- Duplicate folder titles under the same parent are merged by normalized full folder path.

Browser import rules:

- Chrome imports only `roots.bookmark_bar.children`.
- Chrome excludes `roots.other`, `roots.synced`, and the `Bookmarks Bar` wrapper itself.
- Safari excludes `WebBookmarkTypeProxy` nodes.
- Safari excludes root-level native/system nodes `BookmarksBar`, `BookmarksMenu`, and the native root `com.apple.ReadingList` subtree with all descendants inside that subtree.
- Unknown Chrome or Safari node types fail import.
- Missing required source fields fail import.

Merge roles:

- Safari is current.
- Chrome is incoming.
- If multiple Chrome profiles are discovered, the user chooses exactly one.
- The app discovers browser artifacts automatically and does not support custom import paths in MVP.
- If only one browser artifact is discovered, the app can set up an artifact from that browser after a confirmation dialog.

Merge decisions:

- When both browsers are present, the user explicitly resolves decision occurrences.
- Every explicit decision occurrence shows `Accept` and `Reject` actions.
- Save is disabled until all decision occurrences are resolved.
- Same-URL leaf conflicts allow accepting current, accepting incoming, or rejecting both. Accepting both is invalid.
- One-sided items require accepting or rejecting the candidate.
- Folder conflicts are conflicts between same-path folder tree nodes whose normalized child trees differ.
- Folder conflict candidates can be accepted or rejected on each side. Accepting or rejecting a folder applies recursively to descendants, and descendants can be overridden afterward.
- Rejecting both sides of a folder conflict is allowed. If accepted descendants require the folder path, the folder remains as structural container. Current/Safari title casing wins for such structural folders.

The merge UI shows folder-level summaries, starts collapsed, and expands changed or conflicting descendants. Progress is shown only as resolved decisions over total decisions and percentage. The denominator includes hidden descendants.

The MVP saves only bookmarknot artifacts. It does not write back to Safari or Chrome, export browser-specific files, compare existing bookmarknot artifacts, revert artifacts, or reset artifacts.

The artifact list displays only valid local artifacts sorted by creation time descending.

## Consequences

Bookmarknot has a deterministic, readable, browser-neutral-enough artifact while staying close to Safari's tree vocabulary.

Chrome and Safari can both be adapted into the canonical format, but full browser-native round-tripping is out of scope for the MVP. Browser-native sync fields, Reading List metadata, Chrome checksum data, Chrome sync metadata, and source browser IDs are intentionally excluded.

Hash-addressed immutable artifacts make future history, reset, revert, and sync workflows possible without adding them to the MVP.

Some user data is intentionally excluded by policy, including Chrome `Other Bookmarks`, Chrome `Mobile Bookmarks`, Safari `BookmarksBar`, Safari `BookmarksMenu`, Safari Reading List, and Safari proxy nodes. Unknown or malformed source data fails import rather than being silently skipped.

The no-duplicate-URL rule keeps merge identity simple, but it means users cannot keep the same URL in multiple folders inside bookmarknot artifacts.
