# bookmarknot

Docs-first repository for bookmarknot workflow and repo policy bootstrap.

## Hook Contract

This repo standardizes on `.pre-commit-config.yaml` as the hook contract.
Use "managed by the `pre-commit`/`prek` hook framework" when referring to that contract.
Use a specific Git hook name such as `pre-commit` or `commit-msg` when referring to an enforcing hook.
Any compatible runner is acceptable. `prek` is the recommended example runner.

Code contributors are expected to have the following installed locally:
- a compatible `.pre-commit-config.yaml` runner
- `swift-format`
- `SwiftLint`

Recommended example command:

```sh
prek install
```
