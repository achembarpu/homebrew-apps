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
- CI (`ci.yml`) runs `brew style` on all casks and formulae and `brew audit` on changed
  casks and formulae. Do not add `--new` rules there — admission rules (repo notability,
  notarization) don't apply to a personal tap.

## Workflow

Generate a cask:

```bash
./scripts/add-cask.sh <owner>/<repo>            # auto-picks the app zip/dmg
./scripts/add-cask.sh <owner>/<repo> --re-sign  # + postflight re-sign block
./scripts/add-cask.sh <owner>/<repo> --no-write # preview without writing
```

Bump an existing cask (keeps `desc`/`zap`/`caveats`):

```bash
./scripts/add-cask.sh <owner>/<repo> --existing <name>
```

Export `GH_TOKEN` (e.g. `$(gh auth token)`) so the script authenticates its
GitHub API calls; without it you hit anonymous 403 rate limits.

Verify BEFORE committing:

```bash
brew style Casks/<name>.rb Formula/<name>.rb
brew audit --cask achembarpu/tap/<name>   # tap must be tapped: brew tap achembarpu/tap
brew audit --formula achembarpu/tap/<name>
```

Test the real install path AFTER committing and pushing. Never substitute a
hand-unzipped copy in /tmp for this: it tests bytes brew does not ship and
proves nothing about the cask. Downloading an artifact to compute its
`sha256` (see hard rules) is fine — that is forensics, not the test.

1. Push, then refresh the local tap clone. `brew update` updates every tap
   including this one, so no manual `git pull` is needed. Immediately after
   a push, prefer the targeted
   `git -C "$(brew --repository achembarpu/tap)" pull --ff-only`: brew's
   automatic pre-install update is skipped inside its freshness window
   (`HOMEBREW_AUTO_UPDATE_SECS`, default 24h) and may leave the new cask
   invisible ("Cask ... is unavailable").
2. `brew audit --cask achembarpu/tap/<name>`
3. `brew install --cask achembarpu/tap/<name>` — exercises the pinned
   sha256 check, staging, `app` move, and `binary` link end to end.
4. Verify the INSTALLED app, not the downloaded zip: run deep-strict
   `codesign --verify --deep --strict` on the moved `.app` (spot-check a
   bundled binary's TeamIdentifier when signing matters), `which <binary>`,
   and run `<binary> --version`.
5. Clean up scratch files; leave no zip dumps or extracted trees behind in
   `$TMPDIR`.

Full option reference: `./scripts/add-cask.sh --help`.

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

- Casks wrap GUI apps from GitHub releases with `.zip` (preferred) or `.dmg` assets that contain a `.app` bundle. No pkg installers, no non-GitHub hosts.
- Formulas wrap CLI tools and scripts that do not contain a `.app` bundle. Each formula pins an upstream artifact with `version` + `sha256`, no live fetches, no vendored binaries unless the build is from source. Use a GitHub release asset where available; the documented exceptions are `junie-local` (a pinned raw upstream script), `optcgsim` (a site-hosted app archive), and `prime-agent` (an npm tarball whose declared dependencies are resolved during the build). See `junie-local` for a script wrapper and `prime-agent` for an npm tarball pattern.
- Uninstall runs `brew uninstall --cask --zap <name>` for casks (data paths come from the cask's `zap`) and `brew uninstall <name>` for formulae.
