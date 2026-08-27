# Homebrew Package Maintenance Guide

### Item 1: Intake and scope `#intake`

1. Read `AGENTS.md`, this skill, and the relevant neighboring casks or formulae.
2. Run `git status --short` before editing. Preserve unrelated changes.
3. Identify the requested upstream owner/repository or artifact URL.
4. Do not commit, push, install, or perform other external side effects unless
   the user explicitly authorizes them.

### Item 2: Classify the package `#classification`

1. Use a **cask** when the release artifact contains a `.app` bundle.
2. Use a **formula** for a CLI tool, script, source build, or non-app artifact.
3. Prefer a GitHub release asset. Use an exception only when `AGENTS.md`
   documents that package's supported exception.
4. Check neighboring files for an existing package or equivalent capability
   before adding a new one.

### Item 3: Select and pin artifacts `#artifacts`

1. Inspect release metadata and choose the exact stable asset. Prefer `.zip`
   over `.dmg` for casks when both contain the same app.
2. Pin the release version and a 64-character SHA-256 hash.
3. Use `scripts/add-cask.sh <owner>/<repo> --no-write` to preview GitHub casks.
   Pass `--asset`, `--version`, or `--app` when auto-detection is insufficient.
4. If no checksum asset exists, download only the release artifact and run
   `shasum -a 256`. Remove all temporary downloads after inspection.
5. Never use a rolling URL, `:no_check`, a vendored binary, or a source URL
   that does not identify the pinned artifact.

### Item 4: Inspect signing and platform support `#signing`

1. Inspect the app's minimum macOS version and architecture from upstream
   documentation and the artifact. Add `depends_on` only when evidence requires it.
2. Run `codesign --verify --deep --strict` on the unpacked app when signing
   affects the cask decision.
3. Add the repository's `postflight` re-sign block only for an ad-hoc-signed,
   non-notarized release. Never re-sign a valid Developer ID notarized release.
4. Read upstream documentation and bundle identifiers to identify permissions,
   model caches, preferences, and other user data.

### Item 5: Implement the package `#implementation`

1. Match the stanza order and style of neighboring files.
2. Add `livecheck` for a release source that can be checked automatically.
3. Add `zap trash:` for package-owned user data. Leave shared model caches or
   data outside the package's ownership boundary alone.
4. Add caveats for required permissions, first-run downloads, update behavior,
   or other install facts users must know.
5. Add or update the matching README table row. Do not document unverified facts.

### Item 6: Verify local changes `#verification`

Run the narrowest applicable checks before committing:

```bash
brew style Casks/<name>.rb Formula/<name>.rb
ruby -c Casks/<name>.rb
git diff --check
```

Run the tap-qualified audit after the tap is available locally:

```bash
brew audit --cask achembarpu/tap/<name>
brew audit --formula achembarpu/tap/<name>
```

Use only the applicable cask or formula command. Report unavailable audit
checks instead of claiming success.

### Item 7: Verify the real install `#verification`

1. After a user-authorized push, refresh the tapped clone with
   `git -C "$(brew --repository achembarpu/tap)" pull --ff-only`.
2. Run the tap-qualified audit and install the package through Homebrew.
3. Verify the installed app or binary, not a hand-unpacked copy. For apps,
   run `codesign --verify --deep --strict`; for binaries, run `which` and
   `<binary> --version`.
4. Remove scratch files from `$TMPDIR` and report every skipped check.

### Item 8: Commit and release `#release`

1. Before committing, inspect `git status`, `git diff`, and recent history.
2. Stage only intended files and use a concise commit message matching history.
3. Commit and push only when the user explicitly requests both actions.
4. After pushing, verify `git status --short` and that local `HEAD` matches
   `origin/main`. Never amend or force-push.
