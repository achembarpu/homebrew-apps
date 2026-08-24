#!/usr/bin/env bash
set -euo pipefail

# Generate or update a Homebrew cask in this tap from a GitHub release.
#   ./scripts/add-cask.sh <owner>/<repo> [options]
#
# Prints the cask, writes it to Casks/<name>.rb (unless --no-write), and
# leaves style/audit verification to you (see README).
#
# GitHub API requests are authenticated when GH_TOKEN or GITHUB_TOKEN is set
# (e.g. GH_TOKEN="$(gh auth token)"). Without a token you share the anonymous
# per-IP rate limit and will eventually get 403s.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASKS_DIR="$ROOT_DIR/Casks"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: add-cask.sh <owner>/<repo> [options]

Generate a new cask (or update an existing one) from a GitHub release.

Options:
  --asset <name>     Use a specific release asset (by exact name).
  --version <tag>    Pin a specific release tag (default: latest).
  --app <App.app>    App bundle name inside the archive (auto-detected).
  --cask <name>      Cask/file name (default: <repo>, lowercased).
  --macos <symbol>   Add "depends_on macos", e.g. --macos sequoia.
  --arch <arch>      Add "depends_on arch", e.g. --arch arm64.
  --re-sign          Add a postflight that clears quarantine and ad-hoc
                     re-signs the bundle (for not-notarized releases).
  --desc <text>      Short one-line description.
  --name <text>      Human-readable app name.
  --existing <cask>  Update Casks/<cask>.rb (version/sha256/url only).
  --archive <file>   Use a local archive instead of downloading it.
  --force            Overwrite an existing cask file.
  --no-write         Print the generated cask to stdout without writing.
  -h, --help         Show this help.

Environment:
  GH_TOKEN / GITHUB_TOKEN  Sent as a Bearer token on GitHub API requests;
                           avoids anonymous rate limits (403s).
EOF
}

# --- options ------------------------------------------------------------------

REPO=""
ASSET=""
VERSION="latest"
APP_OVERRIDE=""
CASK_NAME=""
MACOS=""
ARCH=""
RESIGN=0
FORCE=0
NO_WRITE=0
LOCAL_ARCHIVE=""
EXISTING=""
DESC=""
NAME_HUMAN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --asset)      ASSET="${2:?--asset needs a value}"; shift 2 ;;
    --version)    VERSION="${2:?--version needs a value}"; shift 2 ;;
    --app)        APP_OVERRIDE="${2:?--app needs a value}"; shift 2 ;;
    --cask)       CASK_NAME="${2:?--cask needs a value}"; shift 2 ;;
    --macos)      MACOS="${2:?--macos needs a value}"; shift 2 ;;
    --arch)       ARCH="${2:?--arch needs a value}"; shift 2 ;;
    --desc)       DESC="${2:?--desc needs a value}"; shift 2 ;;
    --name)       NAME_HUMAN="${2:?--name needs a value}"; shift 2 ;;
    --existing)   EXISTING="${2:?--existing needs a value}"; shift 2 ;;
    --archive)    LOCAL_ARCHIVE="${2:?--archive needs a value}"; shift 2 ;;
    --re-sign)    RESIGN=1; shift ;;
    --force)      FORCE=1; shift ;;
    --no-write)    NO_WRITE=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           die "unknown option: $1 (see --help)" ;;
    *)            [ -n "$REPO" ] && die "unexpected argument: $1"; REPO="$1"; shift ;;
  esac
done

[ -n "$REPO" ] || die "missing <owner>/<repo> argument (see --help)"
[[ "$REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] ||
  die "repo must be <owner>/<repo>, got: $REPO"
if [ "$VERSION" != "latest" ]; then
  [[ "$VERSION" =~ ^[A-Za-z0-9._+-]+$ ]] || die "implausible tag: $VERSION"
fi
case "$DESC$NAME_HUMAN" in
  *'"'*) die "--desc/--name must not contain double quotes" ;;
esac

for tool in curl python3 shasum unzip; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

# --- scratch space; one trap cleans everything ---------------------------------

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/add-cask.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
RELEASE_JSON="$TMP_DIR/release.json"

# --- fetch release metadata (Bearer-authenticated when a token is set) ---------

TOKEN="${GH_TOKEN:-}"
[ -n "$TOKEN" ] || TOKEN="${GITHUB_TOKEN:-}"

API_ARGS=(-sS --retry 3 --connect-timeout 15)
[ -n "$TOKEN" ] && API_ARGS+=(-H "Authorization: Bearer $TOKEN")

if [ "$VERSION" = "latest" ]; then
  api_url="https://api.github.com/repos/${REPO}/releases/latest"
else
  api_url="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
fi

# Deliberately no -f: capture the HTTP status ourselves so failures produce a
# useful message instead of curl's bare exit code. `|| status=000` rescues
# transport-level errors from set -e.
status="$(curl "${API_ARGS[@]}" -o "$RELEASE_JSON" -w '%{http_code}' "$api_url")" || status=000
case "$status" in
  200) ;;
  000) die "could not reach $api_url (network error)" ;;
  403 | 429)
    if [ -n "$TOKEN" ]; then
      die "GitHub API returned $status despite a token (rate limit or revoked token?): $api_url"
    fi
    die "GitHub API returned $status (anonymous rate limit). Set GH_TOKEN, e.g.: GH_TOKEN=\"\$(gh auth token)\" $0 $REPO"
    ;;
  404) die "release not found: $api_url (check <owner>/<repo> and --version)" ;;
  *)   die "GitHub API returned HTTP $status: $api_url" ;;
esac

# --- pick the asset -------------------------------------------------------------

# Prints tab-separated: mode, tag, asset_name, download_url. Reportable
# failures (MISSING_ASSET / NO_ASSETS) exit 1 with the reason on stdout;
# unusable metadata exits 2 with the reason on stderr. `|| true` rescues
# those statuses from set -e; the cases below consume the outcome.
pick_result="$(python3 - "$RELEASE_JSON" "$ASSET" "$(basename "$REPO")" <<'PY'
import json, sys

try:
    with open(sys.argv[1]) as f:
        j = json.load(f)
except Exception as exc:
    print("could not parse release metadata: %s" % exc, file=sys.stderr)
    sys.exit(2)

assets = j.get("assets", [])
want = sys.argv[2]
repobase = sys.argv[3]
tag = j.get("tag_name", "")

def emit(mode, name, url):
    print("\t".join([mode, tag, name, url]))

if want:
    for a in assets:
        if a["name"] == want:
            emit("EXACT", a["name"], a["browser_download_url"])
            sys.exit(0)
    print("MISSING_ASSET\t%s\t%s\t" % (tag, want))
    sys.exit(1)

def app_zips():
    # dSYM archives are debug symbols, never the app. Upstream once shipped
    # them first in the asset list (install.sh #131); ignore them likewise.
    return [a for a in assets
            if a["name"].endswith(".zip") and "dSYM" not in a["name"]]

def dmgs():
    return [a for a in assets if a["name"].endswith(".dmg")]

zips = app_zips()
dmgs = dmgs()

def contains_tag(lst):
    return next((a for a in lst if tag and tag in a["name"]), None)

def exact_match(lst):
    want = "%s-%s.zip" % (repobase, tag)
    return next((a for a in lst if a["name"].lower() == want.lower()), None)

a = (exact_match(zips) or contains_tag(zips)
     or (zips[0] if zips else None)
     or contains_tag(dmgs) or (dmgs[0] if dmgs else None))
if not a:
    names = ", ".join(x["name"] for x in assets) or "(release has no assets)"
    print("NO_ASSETS\t%s\t\t%s" % (tag, names))
    sys.exit(1)
emit("AUTO", a["name"], a["browser_download_url"])
PY
)" || true

IFS=$'\t' read -r PICK_MODE TAG ASSET_NAME DOWNLOAD_URL <<<"${pick_result:-}"

case "${PICK_MODE:-}" in
  MISSING_ASSET) die "release '${TAG:-?}' has no asset named '$ASSET'. See --help for auto-pick rules." ;;
  NO_ASSETS)     die "release '${TAG:-?}' has no .zip or .dmg assets. Assets: $DOWNLOAD_URL" ;;
  "")            die "could not parse release metadata (see message above, if any)" ;;
esac

[ -n "$TAG" ]          || die "could not read tag_name from release metadata"
[ -n "$DOWNLOAD_URL" ] || die "could not resolve download URL for ${ASSET_NAME:-?}"

# --- derive names, download, hash -----------------------------------------------

CASK_NAME="${CASK_NAME:-$(basename "$REPO" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')}"
CASK_NAME="${CASK_NAME#-}"
CASK_NAME="${CASK_NAME%-}"
[[ "$CASK_NAME" =~ ^[a-z0-9-]+$ ]] || die "derived cask name invalid: $CASK_NAME"

VERSION_VALUE="${TAG#v}"
NAME_HUMAN="${NAME_HUMAN:-$(basename "$REPO")}"
HOMEPAGE="https://github.com/${REPO}"

# Tap convention: interpolate #{version} into the cask URL so later bumps via
# --existing keep working. Substituting the bare version covers both the
# .../download/v<ver>/ path segment (tags carry a v prefix) and the asset name.
RUBY_VERSION='#{version}'
CASK_URL="${DOWNLOAD_URL//"$VERSION_VALUE"/$RUBY_VERSION}"

if [ -n "$LOCAL_ARCHIVE" ]; then
  [ -f "$LOCAL_ARCHIVE" ] || die "archive not found: $LOCAL_ARCHIVE"
  ARCHIVE="$LOCAL_ARCHIVE"
  ARCHIVE_BASENAME="$(basename "$LOCAL_ARCHIVE")"
else
  ARCHIVE="$TMP_DIR/$ASSET_NAME"
  ARCHIVE_BASENAME="$ASSET_NAME"
  printf 'Downloading %s (%s)...\n' "$ASSET_NAME" "$VERSION_VALUE" >&2
  curl -fsSL --retry 3 "$DOWNLOAD_URL" -o "$ARCHIVE" ||
    die "download failed: $DOWNLOAD_URL"
fi

printf 'Computing SHA-256...\n' >&2
SHA256="$(shasum -a 256 "$ARCHIVE")"
SHA256="${SHA256%% *}"
[[ "$SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "could not compute sha256 of $ARCHIVE"

# --- discover the .app inside the archive ----------------------------------------

if [ -n "$APP_OVERRIDE" ]; then
  APP_NAME="$APP_OVERRIDE"
elif [[ "$ARCHIVE_BASENAME" == *.dmg ]]; then
  MOUNT="$TMP_DIR/mnt"
  mkdir "$MOUNT"
  hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$ARCHIVE" >/dev/null ||
    die "could not mount $ARCHIVE_BASENAME"
  found="$(find "$MOUNT" -maxdepth 3 -type d -name '*.app' -print -quit 2>/dev/null || true)"
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  if [ -n "$found" ]; then
    APP_NAME="$(basename "$found")"
  else
    APP_NAME=""
  fi
else
  # awk exits after the first .app; unzip then gets SIGPIPE, which pipefail
  # would otherwise turn into a script-killing exit 141. `|| true` absorbs it.
  APP_NAME="$(unzip -Z1 "$ARCHIVE" 2>/dev/null | awk -F/ '$1 ~ /\.app$/ { print $1; exit }' || true)"
fi
[ -n "$APP_NAME" ] || die "could not find a .app inside $ARCHIVE_BASENAME (pass --app '<App.app>')"

# --- write (or update) the cask file ----------------------------------------------

# sed replacements treat & and the | delimiter specially; escape both.
escape_sed_repl() { printf '%s' "$1" | sed -e 's/[&|]/\\&/g'; }

write_cask() {
  local out="$1"
  {
    printf 'cask "%s" do\n' "$CASK_NAME"
    printf '  version "%s"\n' "$VERSION_VALUE"
    printf '  sha256 "%s"\n\n' "$SHA256"
    printf '  url "%s"\n' "$CASK_URL"
    printf '  name "%s"\n' "$NAME_HUMAN"
    [ -n "$DESC" ] && printf '  desc "%s"\n' "$DESC"
    printf '  homepage "%s"\n\n' "$HOMEPAGE"
    printf '  livecheck do\n'
    printf '    url "%s/releases/latest"\n' "$HOMEPAGE"
    printf '    strategy :github_latest\n'
    printf '  end\n\n'
    [ -n "$MACOS" ] && printf '  depends_on macos: :%s\n' "$MACOS"
    [ -n "$ARCH" ] && printf '  depends_on arch: :%s\n' "$ARCH"
    if [ -n "$MACOS" ] || [ -n "$ARCH" ]; then printf '\n'; fi
    printf '  app "%s"\n' "$APP_NAME"
    if [ "$RESIGN" = "1" ]; then
      printf '\n'
      printf '  # Release is ad-hoc signed, not notarized. Clear quarantine and\n'
      printf '  # re-sign locally so first launch works (macOS 26 can hang on a\n'
      printf '  # foreign ad-hoc signature during Gatekeeper scan otherwise).\n'
      printf '  postflight do\n'
      printf '    system_command "/usr/bin/xattr",\n'
      printf '                   args: ["-cr", "#{appdir}/%s"]\n' "$APP_NAME"
      printf '    system_command "/usr/bin/codesign",\n'
      printf '                   args: ["--force", "--deep", "--sign", "-", "#{appdir}/%s"]\n' "$APP_NAME"
      printf '  end\n'
    fi
    printf 'end\n'
  } > "$out"
}

if [ -n "$EXISTING" ]; then
  EXISTING_FILE="$CASKS_DIR/${EXISTING}.rb"
  [ -f "$EXISTING_FILE" ] || die "existing cask not found: $EXISTING_FILE"
  printf 'Updating %s -> v%s (sha256 %s)\n' "$EXISTING_FILE" "$VERSION_VALUE" "$SHA256" >&2
  # Exactly-two-space indent keeps these anchored to the top-level stanzas;
  # a bare ` *url "` would also rewrite the livecheck's (4-space) url line.
  sed -i.bak \
    -e 's|^\(  version "\)[^"]*\("\)|\1'"$(escape_sed_repl "$VERSION_VALUE")"'\2|' \
    -e 's|^\(  sha256 "\)[^"]*\("\)|\1'"$(escape_sed_repl "$SHA256")"'\2|' \
    -e 's|^\(  url "\)[^"]*\("\)|\1'"$(escape_sed_repl "$CASK_URL")"'\2|' \
    "$EXISTING_FILE"
  rm -f "${EXISTING_FILE}.bak"
  printf 'Updated %s (version/sha256/url). Re-run brew style + brew audit.\n' "$EXISTING_FILE"
  exit 0
fi

CASK_FILE="$CASKS_DIR/${CASK_NAME}.rb"
if [ "$NO_WRITE" != "1" ] && [ -e "$CASK_FILE" ] && [ "$FORCE" != "1" ]; then
  die "$CASK_FILE already exists (use --force to overwrite, or --existing to update)"
fi

if [ "$NO_WRITE" = "1" ]; then
  write_cask /dev/stdout
else
  mkdir -p "$CASKS_DIR"
  write_cask "$CASK_FILE"
  printf 'Wrote %s\n' "$CASK_FILE"
  printf 'Verify: brew style %s && brew audit --cask %s\n' "$CASK_FILE" "$CASK_NAME"
  printf 'Then fill in desc/zap/caveats as needed and commit.\n'
fi
