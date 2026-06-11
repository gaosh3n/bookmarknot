# 7. Add a committed Xcode project for UI automation

Date: 2026-06-11

## Status

Accepted

## Context

ADR 0004 chose a SwiftPM-first implementation architecture and explicitly deferred an `.xcodeproj`.

The repository now needs a committed Xcode surface so Xcode-oriented tooling can launch the macOS app and verify SwiftUI behavior against issue acceptance criteria. In particular, `XcodeBuildMCP` needs an Xcode project and shared scheme for local UI automation workflows.

The project should gain that Xcode surface without replacing `Package.swift` as the source of truth for module boundaries and dependencies, and without expanding scope into signing, distribution, notarization, or other packaging concerns.

## Decision

The repository will add a committed `bookmarknot.xcodeproj` and a committed `bookmarknot.xcworkspace` for local macOS app automation.

This decision supersedes ADR 0004 only on the point that the initial scaffold excluded an `.xcodeproj`.

`Package.swift` remains the source of truth for the Swift module graph. The Xcode project is a minimal compatibility wrapper for tooling, not a second authoritative build definition.

The Xcode surface will:

- expose a runnable macOS app target and shared scheme named `bookmarknot`
- compile the existing `Sources/UI` files directly from the repository
- resolve `Application`, `Domain`, and `Infrastructure` through the existing Swift package
- use a fixed development bundle identifier for local runs
- disable code signing for local debug and release builds

The Xcode surface will not, by itself, introduce Xcode-owned test targets, signing workflows, distribution packaging, notarization setup, app icons, asset catalogs, or other product-packaging concerns.

## Consequences

The repository stays SwiftPM-first while gaining a stable Xcode entrypoint for macOS UI automation tools.

Contributors and agents can use one committed Xcode scheme instead of creating machine-local project files.

The repository now carries a small amount of Xcode metadata that must stay aligned with the package and the existing UI entrypoint.
