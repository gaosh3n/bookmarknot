# Repo Guide

## Purpose

- This is a docs-first repository for bookmarknot workflow and repo-policy bootstrap.

## Commands

### Hook Runner

- Recommended example for installing a compatible `.pre-commit-config.yaml` runner: `prek install`

### ADR Tools

- First-time ADR setup, only when introducing the first real ADR: `adr init docs/adr`
- Create a new ADR after ADR setup exists: `adr new <decision-title>`
- For further information, use the built in help: `adr help`

### Project Entrypoints

- There is no `Package.swift`, app target, test runner, or other runnable project entrypoint in this repo today.
- Do not invent build, test, lint, format, or deploy commands in agent output.
- Prefer one documented command per workflow when possible. If multiple commands are required, document the narrowest verified entrypoint for each task.

## Workflow

- ADRs live in `docs/adr/`.
- Do not run bare `adr init`; `adr-tools` defaults bare initialization to `doc/adr`.
- When ADRs are first introduced, run `adr init docs/adr` from the repo root and commit the generated `.adr-dir` file with the first ADR.
- Use the Michael Nygard ADR template saved at `docs/references/adr-template.md` when writing ADR content.

## Testing

- There is no verified automated test command in this repo today.
- Do not claim code is tested unless you ran a real command and report the exact command you used.
- Prefer a single documented test entrypoint over ad hoc per-file commands unless the toolchain makes that impossible.

## Project Structure

```text
/
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
