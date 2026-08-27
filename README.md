# homebrew-tap

Personal Homebrew tap for apps and CLI tools that have no official Homebrew package
(or whose official package you would rather not trust). Every cask and formula here is a thin, pinned wrapper over a
specific upstream artifact (normally a GitHub release): exact `version` + `sha256`, no `:no_check`, no
auto-updating URLs. The cask/formula file is the contract.

## Install

```bash
brew tap achembarpu/tap
brew install --cask achembarpu/tap/<cask>
brew install achembarpu/tap/<formula>
```

Once tapped, the short forms also work: `brew install --cask <cask>` and `brew install <formula>`.

## Update

```bash
brew update
brew upgrade --cask achembarpu/tap/<cask>    # or: brew upgrade --cask <cask>
brew upgrade achembarpu/tap/<formula>        # or: brew upgrade <formula>
```

## Uninstall

```bash
brew uninstall --cask --zap achembarpu/tap/<cask>  # casks, including app data
brew uninstall achembarpu/tap/<formula>             # formulae
```

Formulae do not support cask-style `zap` cleanup. Remove formula-specific
user data manually using the command in the formula's caveats.

## Available casks

| Cask | What | Notes |
| --- | --- | --- |
| `junie` | JetBrains Junie AI coding agent CLI (Apple Silicon & Intel) | Developer ID signed and notarized; no `postflight` needed. Installs `junie.app` and links the CLI onto PATH. Updates via `brew upgrade`, not the binary's built-in self-updater. |
| `mdv` | Native Markdown viewer with history, bookmarks, and a TOC sidebar (Apple Silicon, macOS 13+) | Developer-signed, but the release zip's AppleDouble junk files break the signature seal; the cask clears quarantine and re-signs in `postflight`. History lives in a SQLite DB that `zap` removes. |
| `localvoxtral` | Realtime, fully local dictation menu-bar app (Apple Silicon, macOS 15+) | Releases are ad-hoc signed, not notarized; the cask clears quarantine and re-signs in `postflight`. |
| `mac-dictate-anywhere` | On-device voice dictation for any macOS app (universal, macOS 14+) | Developer ID signed and notarized; requires Microphone and Accessibility permissions. Shared FluidAudio speech models are not removed by `zap`. |
| `nativ` | Local AI workspace for running MLX models natively on Apple silicon (macOS 26+, arm64) | Developer ID signed and notarized; no `postflight` needed. Models download into the shared Hugging Face cache, which `zap` leaves alone. |
| `optcgsim` | Unofficial practice tool for the One Piece Card Game (universal Mac build) | Ad-hoc signed, not notarized; the cask clears quarantine and re-signs in `postflight`. Pins the site's base build (1.42c); newer versions arrive via the in-app auto-patcher. |

## Formulas

| Formula | What | Notes |
| --- | --- | --- |
| `junie-local` | `junie-local-setup` command for the optional local model of the `junie` cask (JetBrains MLX engine + Qwen weights) | Vendored verbatim at a pinned upstream revision — no curl pipes. Upstream hard-gates: Apple M5+, >=40 GB RAM, macOS 26+. Downloads land in ~/.local/share/junie-local, outside brew. |
| `prime-agent` | Self-improving coding and research agent | Node.js formula using the pinned GitHub release package. Requires Node.js 22; npm dependencies are installed into the formula keg. User data under ~/.prime/agent is not removed on uninstall. |
| `qwen-code` | Open-source AI coding agent for the terminal (Apple Silicon & Intel) | Uses Qwen Code's pinned standalone macOS release and bundled Node.js runtime. User configuration is not removed on uninstall. |
| `maki` | Efficient AI coding agent with Lua plugins (Apple Silicon & Intel) | Uses Maki's pinned native macOS release. User configuration and sessions are not removed on uninstall. |

## Adding a cask or formula

Agents should use the repeatable `add-package` workflow in
`.agents/skills/homebrew-package-maintenance/SKILL.md`. It covers artifact
selection, signing, user-data cleanup, README synchronization, and verification.

For GitHub-release casks, the generator remains available:

```bash
./scripts/add-cask.sh <owner>/<repo> --no-write
```

Run `./scripts/add-cask.sh --help` for all options. Formulae and exceptional
artifacts require the manual workflow described by the skill.

## Bumping a cask or formula

```bash
./scripts/add-cask.sh <owner>/<repo> --existing <name>  # casks
```

This rewrites `version`, `sha256`, and `url` in place for casks, keeping your `desc`,
`zap`, and `caveats`. For formulae, bump `version`, `sha256`, and `url` by hand.
Then `brew style`, `brew audit`, commit, push — clients run `brew update && brew upgrade`.

### Updating `optcgsim`

`optcgsim` has no `livecheck` — the app ships via Dropbox/Google Drive, not a
GitHub release, so `add-cask.sh` can't drive it. Run
`./scripts/update-optcgsim.sh --dry-run` first, then the script without flags
(see `.agents/skills/update-optcgsim/SKILL.md` for the full workflow).

### Updating `junie-local`

`junie-local` is pinned to a specific commit of
`jetbrains-junie/junie:local/install.sh` (URL contains the 40-char SHA;
`version` is the commit's `YYYY.MM.DD`). No `livecheck` — the authority is the
latest commit touching that path. Run `./scripts/update-junie-local.sh
--dry-run` first, then the script without flags. It authenticates via
`GH_TOKEN`/`GITHUB_TOKEN`, fetches the latest SHA via the GitHub API, downloads
the raw file, recomputes `sha256`, and rewrites `url`/`version`/`sha256`.

## Automation

`.github/workflows/autobump.yml` runs daily at 06:17 UTC and on
`workflow_dispatch`:

- `autobump` — `brew bump --no-fork --open-pr --tap=achembarpu/tap` for every
  cask and formula that defines a `livecheck` (`junie`, `mdv`, `localvoxtral`,
  `nativ`, `prime-agent`, `qwen-code`, `maki`). Each outdated package gets its
  own PR. The job de-duplicates against open PRs and runs `brew audit` and
  `brew style` inline.

- `bump-optcgsim` — runs `scripts/update-optcgsim.sh` (see above) and opens a
  PR with `peter-evans/create-pull-request` when the RSS version differs.

- `bump-junie-local` — runs `scripts/update-junie-local.sh` (see above) and
  opens a PR when the pinned SHA differs.

There is no separate `brew style`/`brew audit` CI job. Autobump validates its
own changes; for manual bumps, verify locally with `brew style` and
`brew audit` before committing (see Verification above). `brew audit --new`
admission rules do not apply to a personal tap.

## Notes

- The tap itself is MIT licensed ([LICENSE](LICENSE)); each cask and formula additionally
  inherits its upstream app's license.
- Ad-hoc-signed / un-notarized releases are common for small apps. Two
  patterns are safe: `--re-sign` (local `xattr -cr` + ad-hoc re-sign in
  `postflight`, matching what the app's own installer would do) or a
  `preflight`/`installer` step the app ships. If an app needs signing magic
  you don't understand, don't add it here.
