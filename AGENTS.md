# Repo Guide

## Purpose

- This is a SwiftPM-first native macOS application for the Bookmarknot MVP.

## Commands

### Hook Runner

- Recommended example for installing a compatible `.pre-commit-config.yaml` runner: `prek install`

### ADR Tools

- First-time ADR setup, only when introducing the first real ADR: `adr init docs/adr`
- Create a new ADR after ADR setup exists: `adr new <decision-title>`
- For further information, use the built in help: `adr help`

### Project Entrypoints

- Build the package: `swift build`
- Run the macOS application: `swift run bookmarknot`
- Run the non-UI test suite: `swift test`
- Prefer one documented command per workflow when possible. If multiple commands are required, document the narrowest verified entrypoint for each task.

## Workflow

- ADRs live in `docs/adr/`.
- Do not run bare `adr init`; `adr-tools` defaults bare initialization to `doc/adr`.
- When ADRs are first introduced, run `adr init docs/adr` from the repo root and commit the generated `.adr-dir` file with the first ADR.
- Use the Michael Nygard ADR template saved at `docs/references/adr-template.md` when writing ADR content.

## Testing

- Use `swift test` as the verified automated test entrypoint.
- Domain tests cover canonical artifacts and generation decisions; Application tests use fake services; Infrastructure tests use isolated temporary directories.
- Do not claim code is tested unless you ran a real command and report the exact command you used.
- Prefer a single documented test entrypoint over ad hoc per-file commands unless the toolchain makes that impossible.

## Project Structure

```text
/
├── Package.swift                              # SwiftPM package and dependency boundaries
├── Sources/
│   ├── UI/                                    # SwiftUI app and presentation
│   ├── Application/                           # complete user-operation coordination
│   ├── Domain/                                # Bookmarknot business rules
│   └── Infrastructure/                        # filesystem and browser adapters
├── Tests/
│   ├── ApplicationTests/
│   ├── DomainTests/
│   └── InfrastructureTests/
├── CONTEXT.md                                 # canonical repo language
└── docs/
    ├── agents/
    │   ├── domain.md                         # domain-doc consumption rules
    │   ├── issue-tracker.md                  # GitHub issue workflow
    │   └── triage-labels.md                  # GitHub triage label mapping
    └── references/
        ├── a-complete-guide-to-agents-md.md # source guidance behind this doc's maintenance
        └── adr-template.md                  # Michael Nygard ADR template
```

## Boundaries

- Do not invent repository facts. If a command, target, directory, workflow, or convention does not exist, say so plainly.
- Do not backfill speculative future architecture into repo docs.
- If a change adds runnable code, tooling, tests, or agent-facing documentation, update `AGENTS.md` or the linked progressive-disclosure docs in the same change.
- Prefer small, reversible documentation updates over broad policy language that is not yet enforced by the repo.
