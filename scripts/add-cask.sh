#!/usr/bin/env bash
set -euo pipefail

# Generate or update a Homebrew cask in this tap from a GitHub release.
#   ./scripts/add-cask.sh <owner>/<repo> [options]
# Prints the cask, writes it to Casks/<name>.rb (unless --no-write), and
# leaves style/audit verification to you (see README).

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
EOF
}

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
    --no-write)   NO_WRITE=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           die "unknown option: $1 (see --help)" ;;
    *)            [ -n "$REPO" ] && die "unexpected argument: $1"; REPO="$1"; shift ;;
  esac
done

[ -n "$REPO" ] || die "missing <owner>/<repo> argument (see --help)"
[[ "$REPO" == */* ]] || die "repo must be <owner>/<repo>, got: $REPO"

# --- resolve release metadata from the GitHub API ---------------------------
fetch_release_json() {
  local api_url tmp
  if [ "$VERSION" = "latest" ]; then
    api_url="https://api.github.com/repos/${REPO}/releases/latest"
  else
    api_url="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
  fi
  tmp="$(mktemp)"
  curl -fsSL --retry 3 "$api_url" -o "$tmp" || die "could not fetch release metadata from $api_url"
  printf '%s\n' "$tmp"
}

release_json="$(fetch_release_json)"
trap 'rm -f "$release_json"' EXIT

# Prints tab-separated: mode, tag, asset_name, download_url. Dies on failure.
pick_result="$(python3 - "$release_json" "$ASSET" "$(basename "$REPO")" <<'PY'
import json, sys
j = json.load(open(sys.argv[1]))
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
    print("MISSING_ASSET\t%s\t%s\t%s" % (tag, want, ""))
    sys.exit(1)

# dSYM archives are debug symbols, never the app. Upstream once shipped them
# first in the asset list (install.sh #131); ignore them here the same way.
def app_zips():
    return [a for a in assets if a["name"].endswith(".zip") and "dSYM" not in a["name"]]

def dmgs():
    return [a for a in assets if a["name"].endswith(".dmg")]

zips = app_zips()
dms = dmgs()

def exact_match(lst):
    want = "%s-%s.zip" % (repobase, tag)
    for a in lst:
        if a["name"].lower() == want.lower():
            return a
    return None

def contains_tag(lst):
    for a in lst:
        if tag and tag in a["name"]:
            return a
    return None

a = exact_match(zips) or contains_tag(zips) or (zips[0] if zips else None) \
    or contains_tag(dms) or (dms[0] if dms else None)
if not a:
    names = ", ".join(x["name"] for x in assets) or "(release has no assets)"
    print("NO_ASSETS\t%s\t\t%s" % (tag, names))
    sys.exit(1)
emit("AUTO", a["name"], a["browser_download_url"])
PY
)"
IFS=$'\t' read -r PICK_MODE TAG ASSET_NAME DOWNLOAD_URL <<<"$pick_result"

case "$PICK_MODE" in
  MISSING_ASSET) die "release '$TAG' has no asset named '$ASSET'. See --help for auto-pick rules." ;;
  NO_ASSETS)     die "release '$TAG' has no .zip or .dmg assets. Assets: $DOWNLOAD_URL" ;;
esac

[ -n "$TAG" ]        || die "could not read tag_name from release metadata"
[ -n "$DOWNLOAD_URL" ] || die "could not resolve download URL for $ASSET_NAME"

# --- derive names and download the archive for sha256/app discovery --------
CASK_NAME="${CASK_NAME:-$(printf '%s' "$(basename "$REPO")" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')}"
CASK_NAME="${CASK_NAME#-}"
CASK_NAME="${CASK_NAME%-}"
[[ "$CASK_NAME" =~ ^[a-z0-9-]+$ ]] || die "derived cask name invalid: $CASK_NAME"

VERSION_VALUE="${TAG#v}"
NAME_HUMAN="${NAME_HUMAN:-$(basename "$REPO")}"
HOMEPAGE="https://github.com/${REPO}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"; rm -f "$release_json"' EXIT

if [ -n "$LOCAL_ARCHIVE" ]; then
  [ -f "$LOCAL_ARCHIVE" ] || die "archive not found: $LOCAL_ARCHIVE"
  ARCHIVE="$LOCAL_ARCHIVE"
else
  ARCHIVE="$TMP_DIR/$ASSET_NAME"
  printf 'Downloading %s (%s)...\n' "$ASSET_NAME" "$VERSION_VALUE" >&2
  curl -fL --retry 3 "$DOWNLOAD_URL" -o "$ARCHIVE" || die "download failed: $DOWNLOAD_URL"
fi

printf 'Computing SHA-256...\n' >&2
SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
[[ "$SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "could not compute sha256 of $ARCHIVE"

# --- discover the .app inside the archive -----------------------------------
if [ -n "$APP_OVERRIDE" ]; then
  APP_NAME="$APP_OVERRIDE"
elif [[ "$ASSET_NAME" == *.dmg ]]; then
  MOUNT="$(mktemp -d)"
  hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$ARCHIVE" >/dev/null 2>&1 || die "could not mount $ASSET_NAME"
  APP_NAME="$(find "$MOUNT" -maxdepth 3 -type d -name '*.app' -print -quit 2>/dev/null | xargs -I{} basename {})"
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rmdir "$MOUNT" 2>/dev/null || true
else
  # awk exits after the first .app; unzip then gets SIGPIPE, which pipefail
  # would otherwise turn into a script-killing exit 141. `|| true` absorbs it.
  APP_NAME="$(unzip -Z1 "$ARCHIVE" 2>/dev/null | awk -F/ '$1 ~ /\.app$/ { print $1; exit }' || true)"
fi
[ -n "$APP_NAME" ] || die "could not find a .app inside $ASSET_NAME (pass --app '<App.app>')"

# --- write (or update) the cask file -----------------------------------------
write_cask() {
  local out="$1"
  {
    printf 'cask "%s" do\n' "$CASK_NAME"
    printf '  version "%s"\n' "$VERSION_VALUE"
    printf '  sha256 "%s"\n\n' "$SHA256"
    printf '  url "%s"\n' "$DOWNLOAD_URL"
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
    -e 's|^\(  version "\)[^"]*\("\)|\1'"${VERSION_VALUE}"'\2|' \
    -e 's|^\(  sha256 "\)[^"]*\("\)|\1'"${SHA256}"'\2|' \
    -e 's|^\(  url "\)[^"]*\("\)|\1'"${DOWNLOAD_URL}"'\2|' \
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
