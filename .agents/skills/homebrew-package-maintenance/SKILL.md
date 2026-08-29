---
name: homebrew-package-maintenance
description: Add, update, and verify Homebrew casks and formulae in this tap. Use when an agent receives an upstream package URL or must maintain a package artifact.
license: Apache-2.0
compatibility: all
metadata:
  version: "1.0.0"
  tags: "intake classification artifacts signing implementation verification release"
---

# Homebrew Package Maintenance

## When to use

Load this skill when adding or updating a cask or formula in this repository.
It defines the repeatable intake, artifact inspection, implementation, and
verification workflow. Use the repository `AGENTS.md` for non-negotiable rules.

## Tag index

| Tag | Items | Description |
| --- | --- | --- |
| `#intake` | 1 | Establish scope and inspect repository state |
| `#classification` | 2 | Choose cask or formula and select the artifact |
| `#artifacts` | 3 | Pin and inspect the upstream bytes |
| `#signing` | 4 | Decide whether re-signing is required |
| `#implementation` | 5 | Write the package and README entry |
| `#verification` | 6-7 | Run local and post-push checks |
| `#release` | 8 | Commit and push only when authorized |

## Full guide

The complete guide lives in [`references/guide.md`](references/guide.md). Load
only the Item you need — grep for `### Item N` or a `#tag` to jump directly.

For formulae with conditional architecture URLs, use
`scripts/update-arch-formula.sh <formula> --dry-run` before a full update.
