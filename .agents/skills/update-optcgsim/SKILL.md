---
name: update-optcgsim
description: >
  Use when asked to "update the optcgsim cask", "bump optcgsim", or check for
  an "optcgsim new version": runs the automated bump script for the optcgsim
  cask in this repo.
---

# Updating the optcgsim cask

`optcgsim` is the one cask in this tap that `add-cask.sh` cannot drive: the
app ships only via a Dropbox link on https://optcgsim.com/ — no GitHub
releases, no livecheck, no published checksums. `scripts/update-optcgsim.sh`
automates the manual bump end to end: read the version from the site's RSS
feed, scrape the Mac Dropbox URL, download the zip (~711 MiB), compute the
sha256, verify the downloaded binary really is the announced version, rewrite
the cask, and run `brew style` + `brew audit`.

## When to use

Run this whenever the user asks to update the optcgsim cask or check whether
a new optcgsim version is out. The script exists because the manual bump
depends on three things that are easy to get wrong: which version is current
(the RSS feed), which URL serves the build (scraped fresh each run), and
whether the download really matches (the binary truth-check).

## Step-by-step

1. Check the plan without downloading or writing:

   ```bash
   ./scripts/update-optcgsim.sh --dry-run
   ```

2. Review the plan: old version, new version, URL, download size. If it says
   "already up to date", stop — nothing to do.

3. Run the bump:

   ```bash
   ./scripts/update-optcgsim.sh
   ```

   This downloads ~711 MiB, computes the sha256, and refuses to rewrite the
   cask if the binary version string or the `<version>_Mac/OPTCGSim.app` zip
   entry disagrees.

4. Confirm the script's summary shows `brew style: pass` and `brew audit:
   pass` (the audit runs against the tap copy the script synced).

5. Commit `Casks/optcgsim.rb` (and, if the version text in its `caveats` or
   the README table went stale, those edits too) — the script never commits.

## Gotchas

- The Dropbox URL's filename segment is vestigial: the site's Mac link may
  say `1_30d_Mac.zip` while the zip actually holds the 1.42c build. NEVER
  read the version from the URL filename.
- The RSS feed (https://optcgsim.com/feed/) is the version authority — the
  newest post title, first token matching `[0-9]+\.[0-9]+[a-z]*`.
- The script truth-checks the download: it extracts `Assembly-CSharp.dll`
  from the zip and greps its string heap for `sim version:`; a mismatch
  aborts the update.
- The zip's top-level folder must stay `<version>_Mac/` (with `OPTCGSim.app`
  inside); the script aborts if the naming changed, since the cask's
  `only_path:` depends on it.
- The download is ~711 MiB; the script skips it entirely when the RSS
  version matches the cask version.
- Dropbox `rlkey`/`st` tokens rotate; the script scrapes fresh ones from the
  site every run, so never hard-code the URL.
- Since v1.40a the app self-updates in-app via its auto-patcher, so the site
  can ship a newer build without a new RSS post; the cask pins the base build
  the site's download link serves.

## Workflow Summary

1. `./scripts/update-optcgsim.sh --dry-run`
2. Review the plan; if not "already up to date", run `./scripts/update-optcgsim.sh`
3. Confirm `brew style` and `brew audit` passed in the summary
4. Commit `Casks/optcgsim.rb` separately — never commit unless the user asks
