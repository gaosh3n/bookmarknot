# 4. Define MVP implementation architecture

Date: 2026-06-08

## Status

Accepted

## Context

ADR 0002 defines the MVP bookmark artifact format. ADR 0003 defines the MVP macOS UI flow.

The repository now needs an implementation architecture for turning those product decisions into a runnable Swift project. The architecture must be suitable for a Vim-first workflow, avoid unnecessary Xcode project scaffolding, and keep the MVP focused on local import, review, generation, and storage of Bookmarknot-owned artifacts.

The implementation architecture should not reopen the settled artifact format or UI flow. It should also avoid deciding lower-level implementation tactics such as fixture layout, concrete type names, function shapes, implementation order, app packaging, signing, or distribution.

## Decision

The MVP implementation will be a SwiftPM-first Swift project.

The initial project structure will be:

```text
bookmarknot/
├── Package.swift
├── Sources/
│   ├── UI/
│   ├── Application/
│   ├── Domain/
│   └── Infrastructure/
├── Tests/
│   ├── ApplicationTests/
│   ├── DomainTests/
│   └── InfrastructureTests/
├── docs/
├── CONTEXT.md
├── AGENTS.md
├── README.md
├── feature_list.json
└── LICENSE
```

`Package.swift` lives at the repository root. `Sources/` and `Tests/` are top-level implementation directories.

The SwiftPM executable product is named `bookmarknot`.

The initial scaffold will target the current local toolchain:

- Swift tools version `6.3`.
- macOS platform `.v26`.

The MVP will use Swift, SwiftUI, Foundation, and Apple-provided frameworks only. It will not add third-party package dependencies.

The source areas are:

- `UI`: SwiftUI app entrypoint, windows, sidebar, configuration views, generation wizard, runtime log display, visible dialogs, and user preference presentation.
- `Application`: coordination of complete user operations such as source refresh and generation across domain rules and infrastructure services.
- `Domain`: the business brain of Bookmarknot, including app-designed bookmark artifact meaning, import policy, canonicalization rules, validation, duplicate handling, decision rules, and merge semantics.
- `Infrastructure`: the technical muscle, including browser file discovery, reading Chrome JSON and Safari plist data, app-support directory management, source-cache writes, immutable artifact writes, hashing implementation, and runtime log file I/O.

The dependency rule is unidirectional toward domain knowledge:

- `Domain` must not depend on `UI`, `Application`, or `Infrastructure`.
- `UI` and `Application` may depend on `Domain`.
- `Infrastructure` may depend on `Domain` when translating outside-world data into Bookmarknot's app-designed representation.
- The exact dependency relationship between `Application` and `Infrastructure` may be refined during implementation, but it must not require `Domain` to depend outward.

`Domain` represents Bookmarknot's own bookmark and decision language. Chrome-specific and Safari-specific file formats are outside-world technical concerns and belong in `Infrastructure`; the business interpretation of imported bookmark contents belongs in `Domain`.

The MVP will store durable state in files only. It will not introduce a database. Durable state consists of canonical JSON bookmark artifacts, converted source caches and index files, runtime logs, and lightweight UI preferences.

The MVP will run as one process. It will not introduce an XPC service, helper executable, launch agent, daemon, privileged component, or background service. This is an MVP constraint, not a permanent rule; future export, sync, permission, or continuous-operation requirements may reopen it.

The initial scaffold will not include an `.xcodeproj`, app icons, asset catalogs, custom `Info.plist`, entitlements, signing configuration, notarization configuration, distribution packaging, or scripts for building a final `.app` bundle. Those are packaging and distribution concerns for a later decision.

Non-UI tests will use Swift Testing. The initial scaffold will include `ApplicationTests`, `DomainTests`, and `InfrastructureTests`. It will not include UI tests initially.

`Exporter` is useful future product vocabulary for inside-to-outside workflows such as iCloud synchronization or browser write-back, but it is not part of the MVP scaffold and will not be created as a source directory or target now.

## Consequences

The project can be developed primarily from a terminal and Vim while still using SwiftPM's standard top-level `Sources/` and `Tests/` layout.

The implementation architecture stays aligned with ADR 0002 and ADR 0003 without adding premature packaging, distribution, database, helper-process, or third-party dependency decisions.

The source tree separates user interface, operation coordination, business rules, and technical file/browser concerns. This makes it easier to keep Bookmarknot's artifact and decision rules independent from SwiftUI and browser filesystem details.

Starting with Swift `6.3` and macOS `.v26` optimizes for the current local environment rather than backward compatibility. Supporting older macOS or Swift versions would require a later decision.

Deferring `.app` packaging, signing, and distribution keeps the first implementation scaffold small, but it means a later ADR will be needed before Bookmarknot is packaged for normal macOS app distribution.
