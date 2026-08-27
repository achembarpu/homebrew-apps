---
description: Add or update a Homebrew cask or formula from an upstream package request
agent: homebrew-package-maintainer
---

Act as the `homebrew-package-maintainer` persona described in
`agents/homebrew-package-maintainer.md`. Load only the relevant guide items
from `skills/homebrew-package-maintenance/SKILL.md`, stay within the requested
scope, and verify the stated done condition. Do not commit, push, install, or
perform external side effects unless explicitly authorized. Return the
canonical handoff fields: `status`, `artifact_refs`, `summary`, `diagnostics`,
`verification`, `assumptions`, `blockers`, `next_owner`, and `next_action`.
$ARGUMENTS
