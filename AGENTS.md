# homebrew-apps — agent guide

Personal Homebrew tap for apps without an official cask. **The cask file is
the contract**: each cask pins an exact `version` + `sha256` and wraps a
specific GitHub release asset. No `:no_check`, no rolling URLs, no vendored
binaries.

## Hard rules

- Every cask MUST pin `version` + `sha256` and MUST point `url` at a real
  release asset. Never add `:no_check` or a `live`/rolling URL. If the
  release has no `.sha256` asset, download the artifact and compute the hash
  with `shasum -a 256`.
- Never vendor or embed an app's binaries here. The cask is a thin wrapper.
- Ad-hoc-signed / un-notarized releases are common and fine, but they MUST
  ship a `postflight` that clears quarantine and re-signs locally (`xattr -cr`
  then `codesign --force --deep --sign -`) — `scripts/add-cask.sh --re-sign`
  emits this. If an app needs signing magic you can't explain, don't add it.
- Add a `zap trash:` list for any app that stores data, and `caveats` for
  permission gotchas (e.g. a silently-dropped Accessibility grant after
  updates).
- CI (`ci.yml`) runs `brew style` on all casks and `brew audit` on changed
  casks. Do not add `--new` rules there — admission rules (repo notability,
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

Verify BEFORE committing:

```bash
brew style Casks/<name>.rb
brew audit --cask achembarpu/apps/<name>   # tap must be tapped: brew tap achembarpu/apps
```

Full option reference: `./scripts/add-cask.sh --help`.

## Conventions

- `brew style --fix` is the arbiter of stanza order (`version, sha256, url,
  name, desc, homepage, livecheck, depends_on, app, postflight, zap,
  caveats`) — run it, don't fight it.
- `desc` must start with a capital letter (a style cop).
- Default `depends_on macos: :sequoia` and `depends_on arch: :arm64` only when
  the app actually requires them; don't guess.
- Keep the README's cask table in sync when adding a cask.

## Scope

- Casks come from GitHub releases with `.zip` (preferred) or `.dmg` assets.
  No pkg installers, no non-GitHub hosts.
- Uninstall runs `brew uninstall --cask --zap <name>`; data paths come from
  the cask's `zap`.
