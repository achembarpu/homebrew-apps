# homebrew-apps

Personal Homebrew tap for apps that have no official cask (or whose official
cask you'd rather not trust). Every cask here is a thin, pinned wrapper over a
specific GitHub release: exact `version` + `sha256`, no `:no_check`, no
auto-updating URLs. The cask file is the contract.

## Install

```bash
brew tap achembarpu/apps
brew install --cask achembarpu/apps/<name>
```

Once tapped, the short form also works: `brew install --cask <name>`.

## Update

```bash
brew update
brew upgrade --cask achembarpu/apps/<name>    # or: brew upgrade --cask <name>
```

## Uninstall (including app data)

```bash
brew uninstall --cask --zap achembarpu/apps/<name>
```

## Available casks

| Cask | What | Notes |
| --- | --- | --- |
| `localvoxtral` | Realtime, fully local dictation menu-bar app (Apple Silicon, macOS 15+) | Releases are ad-hoc signed, not notarized; the cask clears quarantine and re-signs in `postflight`. |
| `optcgsim` | Unofficial practice tool for the One Piece Card Game (universal Mac build) | Ad-hoc signed, not notarized; the cask clears quarantine and re-signs in `postflight`. Pins the site's base build (1.42b); newer versions arrive via the in-app auto-patcher. |

## Adding a cask

The fast path — generate a cask from a GitHub release:

```bash
./scripts/add-cask.sh <owner>/<repo>                  # latest release, auto-detected zip/dmg
./scripts/add-cask.sh <owner>/<repo> --version v1.2.3 # specific tag
./scripts/add-cask.sh <owner>/<repo> --re-sign        # app ships ad-hoc signed; clear + re-sign postflight
./scripts/add-cask.sh <owner>/<repo> --macos sequoia --arch arm64
```

Then, by hand if needed: fill in `desc`/`name`, add a `zap trash:` list for
the app's data directories, and add `caveats`. Validate before committing:

```bash
brew style Casks/<name>.rb
brew audit --cask achembarpu/apps/<name>   # requires the tap to be tapped (brew tap achembarpu/apps)
```

Full option reference: `./scripts/add-cask.sh --help`.

Manual alternative: copy an existing `Casks/*.rb`, set `version`, `sha256`
(from the release's `.sha256` asset), `url`, and `app "<App.app>"`.

## Bumping a cask's version

```bash
./scripts/add-cask.sh <owner>/<repo> --existing <name>
```

This rewrites `version`, `sha256`, and `url` in place, keeping your `desc`,
`zap`, and `caveats`. Then `brew style`, `brew audit`, commit, push — clients
run `brew update && brew upgrade --cask <name>`.

### Updating `optcgsim`

`optcgsim` has no `livecheck` — the app ships via Dropbox/Google Drive, not a
GitHub release, so `add-cask.sh` can't drive it. Run
`./scripts/update-optcgsim.sh --dry-run` first, then the script without flags
(see `.agents/skills/update-optcgsim/SKILL.md` for the full workflow).

## CI

`.github/workflows/ci.yml` runs on every push/PR to `main`:

- `brew style Casks/*.rb` — offline, structural (all casks)
- `brew audit --cask` — only the casks changed in the push/PR

`brew audit`'s `--new` admission rules (repo notability, notarization) do not
apply to a personal tap; plain audit is the bar here.

## Notes

- The tap itself is MIT licensed ([LICENSE](LICENSE)); each cask additionally
  inherits its upstream app's license.
- Ad-hoc-signed / un-notarized releases are common for small apps. Two
  patterns are safe: `--re-sign` (local `xattr -cr` + ad-hoc re-sign in
  `postflight`, matching what the app's own installer would do) or a
  `preflight`/`installer` step the app ships. If an app needs signing magic
  you don't understand, don't add it here.
