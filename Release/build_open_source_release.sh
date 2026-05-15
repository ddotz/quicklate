#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-zip}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/script"
BUILD_NUMBER_DEFAULT="$(date -u +%Y%m%d%H%M)"
# shellcheck source=app_metadata.sh
source "$SCRIPT_DIR/app_metadata.sh"
RELEASE_DIR="$ROOT_DIR/Release"
BUILD_DIR="$RELEASE_DIR/build"
PRODUCT_DIR="$RELEASE_DIR/product"
APP_BUNDLE="$PRODUCT_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_PATH="$PRODUCT_DIR/$APP_NAME-$VERSION-$BUILD_NUMBER.zip"
STABLE_ZIP_PATH="$PRODUCT_DIR/$APP_NAME-$VERSION.zip"

usage() {
  cat <<EOF
usage: $0 [zip]

zip  Build an Apache 2.0 open-source release app bundle and ZIP.

Optional:
  BUNDLE_ID, VERSION, BUILD_NUMBER, MIN_SYSTEM_VERSION
EOF
}

case "$MODE" in
  zip)
    ;;
  --help|-h|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

cd "$ROOT_DIR"

rm -rf "$BUILD_DIR" "$PRODUCT_DIR"
mkdir -p "$BUILD_DIR" "$APP_MACOS" "$APP_RESOURCES"

swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

install -m 755 "$BUILD_BINARY" "$APP_BINARY"
install -m 644 "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
install -m 644 "$ROOT_DIR/Resources/MenuBarIcon.png" "$APP_RESOURCES/MenuBarIcon.png"
install -m 644 "$ROOT_DIR/Resources/QuickLateLogo.png" "$APP_RESOURCES/QuickLateLogo.png"
install -m 644 "$ROOT_DIR/LICENSE" "$APP_RESOURCES/LICENSE"
install -m 644 "$ROOT_DIR/NOTICE" "$APP_RESOURCES/NOTICE"

"$SCRIPT_DIR/write_info_plist.sh" "$INFO_PLIST" local

/usr/bin/plutil -lint "$INFO_PLIST"

CODESIGN_ARGS=(
  --force
  --deep
  --strict
  --options runtime
  --sign "$SIGNING_IDENTITY"
)

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  CODESIGN_ARGS+=(--timestamp=none)
fi

/usr/bin/codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

/usr/bin/ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
/usr/bin/ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$STABLE_ZIP_PATH"
echo "Built open-source release app: $APP_BUNDLE"
echo "Built open-source release zip: $ZIP_PATH"
echo "Built stable release zip: $STABLE_ZIP_PATH"
