# Repo Guide

## Commands

- There is no `Package.swift`, app target, test runner, or other runnable project entrypoint in this repo today.
- Do not invent build, test, lint, format, or deploy commands in agent output.
- If a change adds runnable code or tooling, that same change must update this section with the minimum verified commands for local development.
- Prefer one documented command per workflow when possible. If multiple commands are required, document the narrowest verified entrypoint for each task.

## Testing

- There is no verified automated test command in this repo today.
- Do not claim code is tested unless you ran a real command and report the exact command you used.
- If a change adds tests, that same change must document the verified test entrypoint in `Commands`.
- Prefer a single documented test entrypoint over ad hoc per-file commands unless the toolchain makes that impossible.

## Project Structure

- The current repo is docs-first. Verified top-level structure today:
  - `AGENTS.md`
  - `.codex/`
  - `docs/agents/`
  - `LICENSE`
- Repo-local Codex hook bootstrap lives under `.codex/`:
  - `.codex/config.toml` enables hooks
  - `.codex/hooks.json` registers repo-local hook handlers
  - `.codex/hooks/` stores the hook scripts
- Agent workflow config lives in `docs/agents/`.
- Issue tracker rules live in `docs/agents/issue-tracker.md`.
- Triage label mapping lives in `docs/agents/triage-labels.md`.
- Domain-doc consumption rules live in `docs/agents/domain.md`.
- This repo uses the canonical triage labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`.
- This repo is configured as single-context: use root `CONTEXT.md` and `docs/adr/` when they exist.
- ADRs should live in `docs/adr/` when the repo starts recording architectural decisions.
- A root `CONTEXT.md` is the default project glossary when one is created.
- Keep agent workflow and repo-policy documentation under `docs/agents/`.
- Add source code under a clearly named top-level directory chosen by the implementation, then update this section in the same change.
- Do not describe directories, modules, or app targets in `AGENTS.md` before they exist.

## Code Style

- There is no repo-specific code style guide yet because there is no source code in the repo.
- When code exists, follow the formatter, linter, and conventions already established in the touched files.
- A change that introduces the first formatter, linter, or style tooling must add its verified command to `Commands` and document the convention here.
- Do not introduce broad style-only churn in unrelated files.

## Git Workflow

- Assume the working tree may contain user changes. Do not overwrite or revert work you did not make unless explicitly asked.
- Keep changes scoped to the task. Avoid incidental renames, moves, or formatting churn.
- Use non-interactive git commands.
- If a task introduces the first enforced branch, commit, or review workflow for this repo, update this section in the same change with only the verified requirements.

## Boundaries

- Do not invent repository facts. If a command, target, directory, workflow, or convention does not exist, say so plainly.
- Do not backfill speculative future architecture into repo docs.
- The first code-bearing or tooling-bearing change must update `AGENTS.md` so commands, testing, and structure remain accurate.
- Prefer small, reversible documentation updates over broad policy language that is not yet enforced by the repo.
