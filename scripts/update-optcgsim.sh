#!/usr/bin/env bash
set -euo pipefail

# Update the optcgsim cask (Casks/optcgsim.rb) from optcgsim.com.
#
# optcgsim has no GitHub releases, no livecheck, and no published checksums:
# the app ships from a Dropbox link on https://optcgsim.com/ whose filename
# segment is VESTIGIAL (it currently says 1_30d_Mac.zip while the zip holds
# the 1.42c build). The version authority is the site's WordPress RSS feed
# (https://optcgsim.com/feed/), the URL comes from scraping the Mac download
# link, and the sha256 is computed from a fresh download (~711 MiB). The
# script aborts rather than rewrite the cask if the downloaded binary does
# not confirm the feed's version or the <version>_Mac/ folder naming changed.
#
#   ./scripts/update-optcgsim.sh            # full bump: download, verify, rewrite
#   ./scripts/update-optcgsim.sh --dry-run  # plan only, no download/no write
#   ./scripts/update-optcgsim.sh --version 1.43a  # override the feed version
#
# The script never commits; commit the cask separately.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASKS_DIR="$ROOT_DIR/Casks"
CASK_FILE="$CASKS_DIR/optcgsim.rb"

FEED_URL="https://optcgsim.com/feed/"
PAGE_URL="https://optcgsim.com/"
ZIP_HINT="~711 MiB"

# Use the tapped checkout when available, but do not assume Homebrew's
# installation prefix. TAP_CASK may be supplied explicitly for unusual setups.
TAP_CASK="${TAP_CASK:-}"
if [ -z "$TAP_CASK" ] && command -v brew >/dev/null 2>&1; then
  tap_root="$(brew --repository achembarpu/apps 2>/dev/null || true)"
  [ -n "$tap_root" ] && TAP_CASK="$tap_root/Casks/optcgsim.rb"
fi

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: update-optcgsim.sh [options]

Bump Casks/optcgsim.rb to the version announced on optcgsim.com.

The version comes from the site's RSS feed (newest post title); the download
URL is scraped from the site's Mac Dropbox link. The script downloads the zip
(~711 MiB), computes the sha256, verifies the binary's embedded version string
and the <version>_Mac/OPTCGSim.app zip entry, then rewrites the cask's
version/sha256/url stanzas in place.

Options:
  --dry-run          Print the bump plan (old -> new version, URL, download
                     needed?) and exit without downloading or writing.
  --version <v>      Override the RSS-derived version (the URL is still
                     scraped; the binary truth-check still runs).
  -h, --help         Show this help.
EOF
}

DRY_RUN=0
VERSION_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=1; shift ;;
    --version)        VERSION_OVERRIDE="${2:?--version needs a value}"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    -*)               die "unknown option: $1 (see --help)" ;;
    *)                die "unexpected argument: $1 (see --help)" ;;
  esac
done

if [ -n "$VERSION_OVERRIDE" ]; then
  [[ "$VERSION_OVERRIDE" =~ ^[0-9]+\.[0-9]+[a-z]*$ ]] \
    || die "invalid --version value: $VERSION_OVERRIDE (expected e.g. 1.43a)"
fi

[ -f "$CASK_FILE" ] || die "cask not found: $CASK_FILE"

# --- current version pinned in the cask ----------------------------------------
CURRENT_VERSION="$(sed -n 's|^  version "\([^"]*\)"$|\1|p' "$CASK_FILE")"
[ -n "$CURRENT_VERSION" ] || die "could not read the current version from $CASK_FILE"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- scrape the authoritative sources -------------------------------------------
printf 'Fetching feed %s ...\n' "$FEED_URL" >&2
curl -fsSL --retry 3 "$FEED_URL" -o "$TMP_DIR/feed.xml" || die "could not fetch $FEED_URL"
printf 'Fetching page %s ...\n' "$PAGE_URL" >&2
curl -fsSL --retry 3 "$PAGE_URL" -o "$TMP_DIR/page.html" || die "could not fetch $PAGE_URL"

meta="$(python3 - "$TMP_DIR/feed.xml" "$TMP_DIR/page.html" "$VERSION_OVERRIDE" <<'PY'
import re, sys
feed = open(sys.argv[1], encoding="utf-8", errors="replace").read()
page = open(sys.argv[2], encoding="utf-8", errors="replace").read()
override = sys.argv[3]

# Version: newest item title in the RSS feed, e.g. "1.42b Release (OP17 Full)".
# The Dropbox filename segment is vestigial — never derive the version from it.
title = None
m = re.search(r"<item>\s*<title>(.*?)</title>", feed, re.S)
if m:
    title = re.sub(r"&(?:#\d+|#x[0-9a-fA-F]+|[a-z]+);", "", m.group(1))
if override:
    version = override
else:
    vm = re.search(r"[0-9]+\.[0-9]+[a-z]*", title) if title else None
    if not vm:
        sys.stderr.write("Error: no version token like 1.42b in the newest feed item title\n")
        if title:
            sys.stderr.write("  (title: %s)\n" % title)
        sys.exit(1)
    version = vm.group(0)

# URL: the Mac Dropbox link in the #download section (exactly one Mac link).
mm = re.search(r'https://www\.dropbox\.com/scl/fi/[^"]*Mac\.zip[^"]*', page)
if not mm:
    sys.stderr.write("Error: no Mac Dropbox link (https://www.dropbox.com/scl/fi/...Mac.zip) found on %s\n" % sys.argv[2])
    sys.exit(1)
url = mm.group(0).replace("&#038;", "&").replace("&amp;", "&")

print("%s\t%s" % (version, url))
PY
)"
IFS=$'\t' read -r TARGET_VERSION SCRAPED_URL <<<"$meta"
[ -n "$TARGET_VERSION" ] || die "could not determine the target version from $FEED_URL"
[ -n "$SCRAPED_URL" ] || die "could not find the Mac Dropbox link on $PAGE_URL"

# --- rebuild the cask URL ---------------------------------------------------------
# Keep the scraped file-id/rlkey/st/dl tokens verbatim; replace only the
# (vestigial) filename segment so the version stays visible in the URL. The
# filename is Ruby-interpolated in the cask so it tracks `version` on bumps.
NEW_FILENAME='1_#{version.tr(".", "_")}_Mac.zip'
NEW_URL="$(printf '%s\n' "$SCRAPED_URL" | sed "s|[^/?]*Mac\.zip|${NEW_FILENAME}|")"
[ "$NEW_URL" != "$SCRAPED_URL" ] || die "could not rebuild the Dropbox URL (no Mac.zip filename segment): $SCRAPED_URL"
# Escape sed's replacement metacharacter: the Dropbox query string always
# contains '&', which sed would otherwise expand to the whole match.
NEW_URL_SED="${NEW_URL//&/\\&}"

# --- plan / early exits ------------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  if [ "$TARGET_VERSION" = "$CURRENT_VERSION" ]; then
    printf 'optcgsim already up to date: RSS version %s == cask version %s\n' "$TARGET_VERSION" "$CURRENT_VERSION"
    printf '  (no download needed)\n'
  else
    printf 'Plan:\n'
    printf '  old version:     %s\n' "$CURRENT_VERSION"
    printf '  new version:     %s\n' "$TARGET_VERSION"
    printf '  url:             %s\n' "$NEW_URL"
    printf '  download needed: yes (%s)\n' "$ZIP_HINT"
    printf '  after download:  verify the binary version string and the <%s_Mac/OPTCGSim.app> zip entry,\n' "$TARGET_VERSION"
    printf '                   then rewrite version/sha256/url in Casks/optcgsim.rb\n'
  fi
  exit 0
fi

if [ "$TARGET_VERSION" = "$CURRENT_VERSION" ]; then
  printf 'optcgsim already up to date: RSS version %s == cask version %s (no download needed)\n' "$TARGET_VERSION" "$CURRENT_VERSION"
  exit 0
fi

# --- download and checksum ------------------------------------------------------------
ARCHIVE="$TMP_DIR/optcgsim.zip"
printf 'Downloading %s (%s)...\n' "$SCRAPED_URL" "$ZIP_HINT" >&2
curl -fL --retry 3 "$SCRAPED_URL" -o "$ARCHIVE" || die "download failed: $SCRAPED_URL"
printf 'Computing SHA-256...\n' >&2
SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
[[ "$SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "could not compute sha256 of $ARCHIVE"

# --- truth checks -----------------------------------------------------------------------
printf 'Verifying zip structure and binary version...\n' >&2
ZIP_LISTING="$TMP_DIR/listing.txt"
unzip -Z1 "$ARCHIVE" > "$ZIP_LISTING" || die "could not list the zip contents of $ARCHIVE"
if ! grep -q "^${TARGET_VERSION//./\\.}_Mac/OPTCGSim.app/" "$ZIP_LISTING"; then
  die "zip does not contain ${TARGET_VERSION}_Mac/OPTCGSim.app — the <version>_Mac folder naming inside the zip changed; refusing to rewrite the cask"
fi
DLL_PATH="$(grep -m1 'Assembly-CSharp\.dll$' "$ZIP_LISTING" || true)"
[ -n "$DLL_PATH" ] || die "could not find Assembly-CSharp.dll inside $ARCHIVE"
unzip -p "$ARCHIVE" "$DLL_PATH" > "$TMP_DIR/Assembly-CSharp.dll" || die "could not extract $DLL_PATH from $ARCHIVE"
BIN_VERSION="$(python3 - "$TMP_DIR/Assembly-CSharp.dll" <<'PY'
import re, sys
raw = open(sys.argv[1], "rb").read()
# The .NET #US string heap stores literals as UTF-16LE; stripping NULs makes
# the ASCII pattern searchable regardless of byte alignment.
stripped = raw.replace(b"\x00", b"")
m = re.search(rb"sim version:\s*([0-9]+\.[0-9]+[a-z]*)", stripped)
if not m:
    sys.exit(2)
sys.stdout.write(m.group(1).decode("ascii", "replace"))
PY
)" || die "could not find 'sim version:' in $DLL_PATH — this does not look like the optcgsim build"
[ -n "$BIN_VERSION" ] || die "could not read the binary version from $DLL_PATH"
if [ "$BIN_VERSION" != "$TARGET_VERSION" ]; then
  die "downloaded binary reports version '$BIN_VERSION' but the RSS feed says '$TARGET_VERSION' — refusing to rewrite the cask"
fi

# --- rewrite the cask (version/sha256/url only) ------------------------------------
# version/sha256 patterns are verbatim from add-cask.sh (those lines have no
# embedded quotes). The url pattern is line-anchored instead of [^"]*-based
# because the interpolated URL itself contains quotes (version.tr(".", "_")),
# so [^"]* would stop at the first one and truncate the rewrite.
printf 'Updating %s: version %s -> %s\n' "$CASK_FILE" "$CURRENT_VERSION" "$TARGET_VERSION" >&2
sed -i.bak \
  -e 's|^\(  version "\)[^"]*\("\)|\1'"${TARGET_VERSION}"'\2|' \
  -e 's|^\(  sha256 "\)[^"]*\("\)|\1'"${SHA256}"'\2|' \
  -e 's|^\(  url "\).*\(",$\)|\1'"${NEW_URL_SED}"'\2|' \
  "$CASK_FILE"
rm -f "${CASK_FILE}.bak"

# --- sync to the tap copy and verify ------------------------------------------------------
STYLE_OK=1
AUDIT_OK=1
AUDIT_NOTE=""
if [ -n "$TAP_CASK" ] && [ -f "$TAP_CASK" ]; then
  printf 'Syncing cask to tap copy %s...\n' "$TAP_CASK" >&2
  cp "$CASK_FILE" "$TAP_CASK"
else
  AUDIT_NOTE=" (audit needs the tap: brew tap achembarpu/apps)"
fi

printf 'Running brew style %s ...\n' "$CASK_FILE" >&2
if ! brew style "$CASK_FILE"; then STYLE_OK=0; fi

if [ -n "$TAP_CASK" ] && [ -f "$TAP_CASK" ]; then
  printf 'Running brew audit --cask achembarpu/apps/optcgsim ...\n' >&2
  if ! brew audit --cask achembarpu/apps/optcgsim; then AUDIT_OK=0; fi
fi

# --- summary ---------------------------------------------------------------------------------
if [ "$STYLE_OK" = "1" ]; then STYLE_RESULT="pass"; else STYLE_RESULT="FAIL"; fi
if [ "$AUDIT_OK" = "1" ]; then AUDIT_RESULT="pass"; else AUDIT_RESULT="FAIL"; fi

printf '\nSummary:\n'
printf '  optcgsim:    %s -> %s\n' "$CURRENT_VERSION" "$TARGET_VERSION"
printf '  sha256:      %s\n' "$SHA256"
printf '  url:         %s\n' "$NEW_URL"
printf '  brew style:  %s\n' "$STYLE_RESULT"
printf '  brew audit:  %s%s\n' "$AUDIT_RESULT" "$AUDIT_NOTE"
printf '  note:        if the cask caveats or README table mention the old version, update them by hand.\n'
printf '  note:        the script never commits — commit Casks/optcgsim.rb separately.\n'

if [ "$STYLE_OK" = "1" ] && [ "$AUDIT_OK" = "1" ]; then
  exit 0
fi
die "verification failed — the cask was rewritten but brew style/audit reported problems; fix and re-run"
