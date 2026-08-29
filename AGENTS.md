# homebrew-tap — agent guide

Personal Homebrew tap for apps and CLI tools without an official Homebrew package. **The cask/formula file is
the contract**: each cask and formula pins an exact `version` + `sha256` and wraps a
specific upstream artifact (normally a GitHub release asset). No `:no_check`, no rolling URLs, no vendored
binaries.

## Hard rules

- Every cask and formula MUST pin `version` + `sha256` and MUST point `url` at a real
  release asset. Never add `:no_check` or a `live`/rolling URL. If the
  release has no `.sha256` asset, download the artifact and compute the hash
  with `shasum -a 256`.
- Never vendor or embed an app's binaries here. Each cask and formula is a thin wrapper.
- Ad-hoc-signed / un-notarized releases are common and fine, but they MUST
  ship a `postflight` that clears quarantine and re-signs locally (`xattr -cr`
  then `codesign --force --deep --sign -`) — `scripts/add-cask.sh --re-sign`
  emits this. If an app needs signing magic you can't explain, don't add it.
- The reverse holds too: NEVER add the re-sign `postflight` to an app that
  ships a valid Developer ID signature + notarization. Re-signing strips the
  real signature and breaks library validation for bundled runtimes (this is
  how the official jetbrains-junie formula corrupted Junie: brew rewrote the
  bundled JRE dylibs and ad-hoc re-signed them, so the launcher refused to
  load them). `codesign --verify --deep --strict` on the installed app is
  the gate.
- Add a `zap trash:` list for any app that stores data, and `caveats` for
  permission gotchas (e.g. a silently-dropped Accessibility grant after
  updates).
- `brew audit --new` admission rules (repo notability, notarization) do not apply
  to a personal tap. Do not add `--new` checks. There is no lint CI job;
  `autobump.yml` validates its own changes via `brew style` and `brew audit`,
  and manual bumps are verified locally before committing.

## Workflow

Use `.agents/commands/add-package.md` for package intake. It dispatches to
`.agents/agents/homebrew-package-maintainer.md`, which loads
`.agents/skills/homebrew-package-maintenance/SKILL.md` for the detailed
workflow. Do not commit or push without explicit authorization.

The existing `scripts/add-cask.sh` remains the generator for GitHub-release
casks. Run `./scripts/add-cask.sh --help` for its options.

### Automation

`.github/workflows/autobump.yml` runs daily at 06:17 UTC and on
`workflow_dispatch`:

- `autobump` — `brew bump --no-fork --open-pr` for every `livecheck`-enabled
  cask/formula (`junie`, `mdv`, `localvoxtral`, `nativ`, `prime-agent`,
  `qwen-code`, `maki`). One PR per outdated package, de-duplicated against
  open PRs.
- `bump-optcgsim` — runs `scripts/update-optcgsim.sh` for the Dropbox-hosted
  cask that has no `livecheck`.
- `bump-junie-local` — runs `scripts/update-junie-local.sh` for the
  commit-pinned `junie-local` formula that has `livecheck skip`; version
  authority is the latest commit touching `local/install.sh`.

No separate lint CI exists. Autobump validates its own edits; for hand-made
bumps run `brew style` + `brew audit` locally as in Verification before
committing.

## Conventions

- `brew style --fix` is the arbiter of stanza order (`version, sha256, url,
  name, desc, homepage, livecheck, depends_on, app, postflight, zap,
  caveats`) — run it, don't fight it.
- `desc` must start with a capital letter (a style cop).
- Default `depends_on macos: :sequoia` and `depends_on arch: :arm64` only when
  the app actually requires them; don't guess.
- If upstream ships separate arm64/amd64 macOS assets, use the `arch` stanza
  with per-arch `sha256` keys instead of pinning `depends_on arch: :arm64`.
- Keep the README's cask and formula tables in sync when adding a cask or formula.

## Scope

- Casks wrap GUI apps from GitHub releases with `.zip` (preferred) or `.dmg` assets that contain a `.app` bundle. The documented non-GitHub exception is `mowglii-mdv`, which uses Mowglii's pinned S3 DMG and Sparkle appcast.
- Formulas wrap CLI tools and scripts that do not contain a `.app` bundle. Each formula pins an upstream artifact with `version` + `sha256`, no live fetches, no vendored binaries unless the build is from source. Use a GitHub release asset where available; the documented exceptions are `junie-local` (a pinned raw upstream script), `optcgsim` (a site-hosted app archive), and `prime-agent` (an npm tarball whose declared dependencies are resolved during the build). See `junie-local` for a script wrapper and `prime-agent` for an npm tarball pattern.
- Uninstall runs `brew uninstall --cask --zap <name>` for casks (data paths come from the cask's `zap`) and `brew uninstall <name>` for formulae.
