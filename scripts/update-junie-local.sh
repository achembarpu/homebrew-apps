#!/usr/bin/env bash
set -euo pipefail

# Update the junie-local formula (Formula/junie-local.rb) from
# jetbrains-junie/junie:local/install.sh.
#
# The formula is intentionally pinned to a specific commit: the URL contains
# a full 40-char SHA and the `version` is the commit's committer date as
# YYYY.MM.DD. The published junie releases are unrelated. There is no
# livecheck; the version authority is the latest commit that touches
# local/install.sh on the default branch.
#
#   ./scripts/update-junie-local.sh            # full bump: check, download, verify, rewrite
#   ./scripts/update-junie-local.sh --dry-run  # plan only, no download/no write
#   ./scripts/update-junie-local.sh --commit <sha>  # override the upstream SHA
#
# The script never commits; commit the formula separately.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA_FILE="$ROOT_DIR/Formula/junie-local.rb"

REPO="jetbrains-junie/junie"
FILE_PATH="local/install.sh"

# Use the tapped checkout when available, but do not assume Homebrew's prefix.
TAP_FORMULA="${TAP_FORMULA:-}"
if [ -z "$TAP_FORMULA" ] && command -v brew >/dev/null 2>&1; then
  tap_root="$(brew --repository achembarpu/tap 2>/dev/null || true)"
  [ -n "$tap_root" ] && TAP_FORMULA="$tap_root/Formula/junie-local.rb"
fi

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: update-junie-local.sh [options]

Bump Formula/junie-local.rb to the latest commit touching local/install.sh.

The latest commit touching that path is the version authority (via
https://api.github.com/repos/jetbrains-junie/junie/commits?path=local/install.sh).
The script downloads the file at the new commit, computes the sha256, derives
the version as the commit's committer date (YYYY.MM.DD), and rewrites the
formula's url/version/sha256 stanzas in place.

Options:
  --dry-run          Print the bump plan (old -> new sha/version, download
                     needed?) and exit without downloading or writing.
  --commit <sha>     Override the API-derived SHA (the version is still the
                     commit's date; the file is still verified).
  -h, --help         Show this help.
EOF
}

DRY_RUN=0
COMMIT_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=1; shift ;;
    --commit)         COMMIT_OVERRIDE="${2:?--commit needs a value}"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    -*)               die "unknown option: $1 (see --help)" ;;
    *)                die "unexpected argument: $1 (see --help)" ;;
  esac
done

if [ -n "$COMMIT_OVERRIDE" ]; then
  [[ "$COMMIT_OVERRIDE" =~ ^[0-9a-f]{40}$ ]] || die "invalid --commit value: $COMMIT_OVERRIDE (expected 40-char hex)"
fi

[ -f "$FORMULA_FILE" ] || die "formula not found: $FORMULA_FILE"

# --- current pin ------------------------------------------------------------
CURRENT_SHA="$(sed -n 's|.*raw\.githubusercontent\.com/jetbrains-junie/junie/\([0-9a-f]\{40\}\)/local/install\.sh.*|\1|p' "$FORMULA_FILE")"
[ -n "$CURRENT_SHA" ] || die "could not read the current SHA from $FORMULA_FILE"
CURRENT_VERSION="$(sed -n 's/^  version "\([^"]*\)"/\1/p' "$FORMULA_FILE")"
[ -n "$CURRENT_VERSION" ] || die "could not read the current version from $FORMULA_FILE"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- fetch latest commit touching the file ----------------------------------
TOKEN="${GH_TOKEN:-}"
[ -n "$TOKEN" ] || TOKEN="${GITHUB_TOKEN:-}"

API_ARGS=(-sS -L --retry 3 --connect-timeout 15 -H "Accept: application/vnd.github.v3+json")
[ -n "$TOKEN" ] && API_ARGS+=(-H "Authorization: Bearer $TOKEN")

# The committed pin is the authority check: latest commit touching the path.
API_URL="https://api.github.com/repos/${REPO}/commits?path=${FILE_PATH}&per_page=1"

if [ -n "$COMMIT_OVERRIDE" ]; then
  TARGET_SHA="$COMMIT_OVERRIDE"
  # Fetch that specific commit to derive its date (still verified).
  COMMIT_JSON="$TMP_DIR/commit.json"
  status="$(curl "${API_ARGS[@]}" -o "$COMMIT_JSON" -w '%{http_code}' "https://api.github.com/repos/${REPO}/commits/${TARGET_SHA}")" || status=000
  case "$status" in
    200) ;;
    000) die "could not reach commit API (network error)" ;;
    403 | 429)
      if [ -n "$TOKEN" ]; then
        die "GitHub API returned $status despite a token (rate limit or revoked token?)"
      fi
      die "GitHub API returned $status (anonymous rate limit). Set GH_TOKEN, e.g.: GH_TOKEN=\"\$(gh auth token)\" $0"
      ;;
    404) die "commit not found: $TARGET_SHA" ;;
    *)   die "GitHub API returned HTTP $status for commit $TARGET_SHA" ;;
  esac
else
  LIST_JSON="$TMP_DIR/commits.json"
  status="$(curl "${API_ARGS[@]}" -o "$LIST_JSON" -w '%{http_code}' "$API_URL")" || status=000
  case "$status" in
    200) ;;
    000) die "could not reach $API_URL (network error)" ;;
    403 | 429)
      if [ -n "$TOKEN" ]; then
        die "GitHub API returned $status despite a token (rate limit or revoked token?): $API_URL"
      fi
      die "GitHub API returned $status (anonymous rate limit). Set GH_TOKEN, e.g.: GH_TOKEN=\"\$(gh auth token)\" $0"
      ;;
    *) die "GitHub API returned HTTP $status: $API_URL" ;;
  esac

  meta="$(python3 - "$LIST_JSON" <<'PY'
import json, sys
j = json.load(open(sys.argv[1]))
if not isinstance(j, list) or not j:
    print("ERROR: no commits returned", file=sys.stderr)
    sys.exit(1)
c = j[0]
sha = c.get("sha", "")
date = (((c.get("commit") or {}).get("committer") or {}).get("date") or
        ((c.get("commit") or {}).get("author") or {}).get("date") or "")
print(f"{sha}\t{date}")
PY
)"
  IFS=$'\t' read -r TARGET_SHA TARGET_DATE_RAW <<<"$meta"
  [ -n "$TARGET_SHA" ] || die "could not determine the latest SHA for $FILE_PATH"
  [ -n "$TARGET_DATE_RAW" ] || die "could not determine the commit date for $TARGET_SHA"

  # Also fetch the single commit JSON to reuse for the version derivation path below.
  COMMIT_JSON="$TMP_DIR/commit.json"
  cp "$LIST_JSON" "$TMP_DIR/list.json"
  # Extract first element as commit json for unified handling
  python3 - "$LIST_JSON" "$COMMIT_JSON" <<'PY'
import json, sys
j = json.load(open(sys.argv[1]))
open(sys.argv[2], "w").write(json.dumps(j[0]))
PY
fi

# Derive TARGET_VERSION as YYYY.MM.DD from the commit's committer date.
# If override was used, COMMIT_JSON already holds that commit; otherwise it
# was extracted above. For the --commit case we haven't set TARGET_DATE_RAW,
# so extract it now.
if [ -z "${TARGET_DATE_RAW:-}" ]; then
  TARGET_DATE_RAW="$(python3 - "$COMMIT_JSON" <<'PY'
import json, sys
j = json.load(open(sys.argv[1]))
date = (((j.get("commit") or {}).get("committer") or {}).get("date") or
        ((j.get("commit") or {}).get("author") or {}).get("date") or "")
print(date)
PY
)"
fi
[ -n "$TARGET_DATE_RAW" ] || die "could not determine commit date for $TARGET_SHA"

TARGET_VERSION="$(python3 - <<PY
import sys
raw = """$TARGET_DATE_RAW"""
# raw is e.g. 2026-08-17T22:59:43Z -> 2026.08.17
print(raw[:10].replace("-", "."))
PY
)"
[[ "$TARGET_VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]] || die "could not derive version from date: $TARGET_DATE_RAW"

NEW_URL="https://raw.githubusercontent.com/${REPO}/${TARGET_SHA}/${FILE_PATH}"
NEW_URL_SED="${NEW_URL//&/\\&}"

# --- plan / early exits ------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  if [ "$TARGET_SHA" = "$CURRENT_SHA" ]; then
    printf 'junie-local already up to date: commit %s == formula pin %s (version %s)\n' "$TARGET_SHA" "$CURRENT_SHA" "$CURRENT_VERSION"
    printf '  (no download needed)\n'
  else
    printf 'Plan:\n'
    printf '  old sha:       %s\n' "$CURRENT_SHA"
    printf '  new sha:       %s\n' "$TARGET_SHA"
    printf '  old version:   %s\n' "$CURRENT_VERSION"
    printf '  new version:   %s\n' "$TARGET_VERSION"
    printf '  url:           %s\n' "$NEW_URL"
    printf '  download needed: yes (install.sh)\n'
    printf '  after download: compute sha256, then rewrite url/version/sha256 in Formula/junie-local.rb\n'
  fi
  exit 0
fi

if [ "$TARGET_SHA" = "$CURRENT_SHA" ]; then
  printf 'junie-local already up to date: commit %s == formula pin %s (version %s) (no download needed)\n' "$TARGET_SHA" "$CURRENT_SHA" "$CURRENT_VERSION"
  exit 0
fi

# --- download and checksum ----------------------------------------------------
ARCHIVE="$TMP_DIR/install.sh"
printf 'Downloading %s ...\n' "$NEW_URL" >&2
curl -fsSL --retry 3 "$NEW_URL" -o "$ARCHIVE" || die "download failed: $NEW_URL"
printf 'Computing SHA-256...\n' >&2
SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
[[ "$SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "could not compute sha256 of $ARCHIVE"

# --- rewrite the formula (url/version/sha256 only) ---------------------------
printf 'Updating %s: %s -> %s (sha %s -> %s)\n' "$FORMULA_FILE" "$CURRENT_VERSION" "$TARGET_VERSION" "$CURRENT_SHA" "$TARGET_SHA" >&2
# Escape sed metachars for the SHA (hex, safe) and version (digits/dots).
# The url pattern is line-anchored because the URL contains no quotes
# needing special handling beyond '&'.
sed -i.bak \
  -e 's|^\(  url "\)[^"]*\("\)|\1'"${NEW_URL_SED}"'\2|' \
  -e 's|^\(  version "\)[^"]*\("\)|\1'"${TARGET_VERSION}"'\2|' \
  -e 's|^\(  sha256 "\)[^"]*\("\)|\1'"${SHA256}"'\2|' \
  "$FORMULA_FILE"
rm -f "${FORMULA_FILE}.bak"

# --- sync to the tap copy and verify -----------------------------------------
STYLE_OK=1
AUDIT_OK=1
AUDIT_NOTE=""
if [ -n "$TAP_FORMULA" ] && [ -f "$TAP_FORMULA" ]; then
  printf 'Syncing formula to tap copy %s...\n' "$TAP_FORMULA" >&2
  cp "$FORMULA_FILE" "$TAP_FORMULA"
else
  AUDIT_NOTE=" (audit needs the tap: brew tap achembarpu/tap)"
fi

printf 'Running brew style %s ...\n' "$FORMULA_FILE" >&2
if ! brew style "$FORMULA_FILE"; then STYLE_OK=0; fi

if [ -n "$TAP_FORMULA" ] && [ -f "$TAP_FORMULA" ]; then
  printf 'Running brew audit --formula achembarpu/tap/junie-local ...\n' >&2
  if ! brew audit --formula achembarpu/tap/junie-local; then AUDIT_OK=0; fi
fi

# --- summary -----------------------------------------------------------------
if [ "$STYLE_OK" = "1" ]; then STYLE_RESULT="pass"; else STYLE_RESULT="FAIL"; fi
if [ "$AUDIT_OK" = "1" ]; then AUDIT_RESULT="pass"; else AUDIT_RESULT="FAIL"; fi

printf '\nSummary:\n'
printf '  junie-local: %s -> %s\n' "$CURRENT_VERSION" "$TARGET_VERSION"
printf '  sha:         %s -> %s\n' "$CURRENT_SHA" "$TARGET_SHA"
printf '  sha256:      %s\n' "$SHA256"
printf '  url:         %s\n' "$NEW_URL"
printf '  brew style:  %s\n' "$STYLE_RESULT"
printf '  brew audit:  %s%s\n' "$AUDIT_RESULT" "$AUDIT_NOTE"
printf '  note:        the script never commits — commit Formula/junie-local.rb separately.\n'

if [ "$STYLE_OK" = "1" ] && [ "$AUDIT_OK" = "1" ]; then
  exit 0
fi
die "verification failed — the formula was rewritten but brew style/audit reported problems; fix and re-run"
