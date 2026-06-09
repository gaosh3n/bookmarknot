# Bookmarknot

Bookmarknot is a SwiftPM-first native macOS application for creating app-owned bookmark artifacts from Google Chrome and Safari sources.

## Requirements

- Swift 6.3
- macOS 26

## Commands

```sh
swift build
swift run bookmarknot
swift test
```

The package uses only Apple-provided frameworks. Its targets separate `UI`, `Application`, `Domain`, and `Infrastructure`, with dependencies directed inward toward `Domain`.

Bookmarknot reads Google Chrome profiles and Safari's native bookmarks plist only after manual refresh. Converted source caches, immutable content-addressed artifacts, and runtime logs are stored under `~/Library/Application Support/Bookmarknot/`.
