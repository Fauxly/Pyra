#!/bin/bash

set -euo pipefail

###############################################################################
# Pyra Debian Package Builder
#
# За один запуск собирает ДВА пакета из одной Release-сборки:
#   rootful  — Architecture: appletvos-arm64, приложение в /Applications
#   rootless — Architecture: iphoneos-arm64,  приложение в /var/jb/Applications
# Само приложение одно и то же: окружение определяется при запуске (PRPathManager).
#
# package/DEBIAN — шаблон control/postinst/postrm. Version и Architecture
# подставляются в копию для каждого варианта, сам шаблон не меняется
# (кроме Version — чтобы в репозитории было видно текущую версию).
###############################################################################

APP_NAME="Pyra"
PACKAGE_ID="com.fauxly.pyra"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PACKAGE_DIR="$SCRIPT_DIR/package"
DEBIAN_TEMPLATE="$PACKAGE_DIR/DEBIAN"
OUTPUT_DIR="$SCRIPT_DIR/output"

# Вариант: "имя|архитектура|префикс пути внутри пакета"
VARIANTS=(
    "rootful|appletvos-arm64|"
    "rootless|iphoneos-arm64|var/jb/"
)

###############################################################################
# Dependencies
###############################################################################

echo "======================================================="
echo "               Pyra Package Builder"
echo "======================================================="

for tool in dpkg-deb rsync find shasum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo
        echo "❌ Missing dependency: $tool"
        exit 1
    fi
done

###############################################################################
# ldid — required for entitlement signing
###############################################################################

LDID_BIN=""

if [ -x "$SCRIPT_DIR/ldid" ]; then
    LDID_BIN="$SCRIPT_DIR/ldid"
elif command -v ldid >/dev/null 2>&1; then
    LDID_BIN="$(command -v ldid)"
fi

if [ -z "$LDID_BIN" ]; then
    echo
    echo "❌ ldid not found."
    echo "   Place ldid binary in $SCRIPT_DIR/ or install it into PATH."
    exit 1
fi

for plist in entitlements.plist entitlements-topshelf.plist; do
    if [ ! -f "$SCRIPT_DIR/$plist" ]; then
        echo
        echo "❌ $plist not found in $SCRIPT_DIR/"
        exit 1
    fi
done

[ -f "$DEBIAN_TEMPLATE/control" ] || {
    echo "❌ Missing $DEBIAN_TEMPLATE/control"
    exit 1
}

echo "Using ldid: $LDID_BIN"

###############################################################################
# Find latest Release build
###############################################################################

echo
echo "Searching Release build..."

APP_SOURCE=$(find \
"$HOME/Library/Developer/Xcode/DerivedData" \
-path "*/Build/Products/Release-appletvos/${APP_NAME}.app" \
-print0 | xargs -0 ls -td | head -n 1)

if [ -z "$APP_SOURCE" ]; then
    echo
    echo "❌ Release build not found."
    echo
    echo "Build Pyra in Release mode first."
    exit 1
fi

echo
echo "Found:"
echo "$APP_SOURCE"

###############################################################################
# Read Info.plist
###############################################################################

INFO_PLIST="$APP_SOURCE/Info.plist"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST")
FULL_VERSION="${VERSION}-${BUILD}"

echo
echo "Version : $VERSION"
echo "Build   : $BUILD"

mkdir -p "$OUTPUT_DIR"

# Версия в шаблоне — для наглядности (Architecture там не важна, её задаёт вариант)
sed -i '' "s/^Version:.*/Version: ${FULL_VERSION}/" "$DEBIAN_TEMPLATE/control"

# Старые раскладки прежних версий скрипта (package/Applications, package/var) — убираем,
# теперь пакеты собираются во временной папке, в package/ остаётся только DEBIAN
rm -rf "$PACKAGE_DIR/Applications" "$PACKAGE_DIR/var"

###############################################################################
# Temporary work directory
###############################################################################

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pyra-deb.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

strip_junk() {
    find "$1" -name ".DS_Store" -delete
    find "$1" -name "._*" -delete
    find "$1" -name ".AppleDouble" -delete
    find "$1" -name ".LSOverride" -delete
    find "$1" -name ".Spotlight-V100" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$1" -name ".Trashes" -type d -exec rm -rf {} + 2>/dev/null || true
}

###############################################################################
# Prepare and sign Pyra.app once (одинаково для обоих вариантов)
###############################################################################

echo
echo "Copying application..."

SIGNED_APP="$WORK_DIR/${APP_NAME}.app"
rsync -a --delete "$APP_SOURCE/" "$SIGNED_APP/"

rm -f "$SIGNED_APP/embedded.mobileprovision"
rm -f "$SIGNED_APP/PkgInfo"
strip_junk "$SIGNED_APP"

echo
echo "Signing app extensions (Top Shelf)..."

# Расширения подписываем ДО основного бинарника — сначала вложенное, потом контейнер.
# Свои entitlements: песочница + чтение TopShelf.json.
if [ -d "$SIGNED_APP/PlugIns" ]; then
    for APPEX in "$SIGNED_APP"/PlugIns/*.appex; do
        [ -d "$APPEX" ] || continue
        APPEX_BIN=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "$APPEX/Info.plist")
        rm -f "$APPEX/embedded.mobileprovision"
        echo "  → $(basename "$APPEX")"
        "$LDID_BIN" -S"$SCRIPT_DIR/entitlements-topshelf.plist" "$APPEX/$APPEX_BIN"
    done
fi

echo
echo "Signing Pyra with entitlements..."

"$LDID_BIN" -S"$SCRIPT_DIR/entitlements.plist" "$SIGNED_APP/$APP_NAME"

echo
echo "Current entitlements:"
"$LDID_BIN" -e "$SIGNED_APP/$APP_NAME"

[ -f "$SIGNED_APP/$APP_NAME" ] || {
    echo "❌ Executable not found."
    exit 1
}

###############################################################################
# Build each variant
###############################################################################

BUILT_DEBS=()

for VARIANT in "${VARIANTS[@]}"; do
    IFS='|' read -r VARIANT_NAME ARCHITECTURE PREFIX <<< "$VARIANT"

    echo
    echo "-------------------------------------------------------"
    echo " Building $VARIANT_NAME ($ARCHITECTURE)"
    echo "-------------------------------------------------------"

    STAGE="$WORK_DIR/stage-$VARIANT_NAME"
    APP_DEST="$STAGE/${PREFIX}Applications/${APP_NAME}.app"
    OUTPUT_DEB="$OUTPUT_DIR/${PACKAGE_ID}_${FULL_VERSION}_${ARCHITECTURE}.deb"

    rm -f "$OUTPUT_DEB"
    mkdir -p "$STAGE" "$(dirname "$APP_DEST")"

    # DEBIAN из шаблона + своя архитектура
    cp -R "$DEBIAN_TEMPLATE" "$STAGE/DEBIAN"
    strip_junk "$STAGE/DEBIAN"
    if grep -q "^Architecture:" "$STAGE/DEBIAN/control"; then
        sed -i '' "s/^Architecture:.*/Architecture: ${ARCHITECTURE}/" "$STAGE/DEBIAN/control"
    else
        echo "Architecture: ${ARCHITECTURE}" >> "$STAGE/DEBIAN/control"
    fi

    rsync -a "$SIGNED_APP/" "$APP_DEST/"

    # Permissions
    find "$STAGE" -type d -exec chmod 755 {} \;
    find "$STAGE" -type f -exec chmod 644 {} \;
    chmod 755 "$APP_DEST/$APP_NAME"

    # Исполняемые файлы расширений — иначе find выше оставит им 644 и они не запустятся
    if [ -d "$APP_DEST/PlugIns" ]; then
        for APPEX in "$APP_DEST"/PlugIns/*.appex; do
            [ -d "$APPEX" ] || continue
            APPEX_BIN=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "$APPEX/Info.plist")
            chmod 755 "$APPEX/$APPEX_BIN"
        done
    fi

    for script in preinst postinst prerm postrm; do
        [ -f "$STAGE/DEBIAN/$script" ] && chmod 755 "$STAGE/DEBIAN/$script"
    done

    dpkg-deb --build --root-owner-group "$STAGE" "$OUTPUT_DEB"

    if dpkg-deb -c "$OUTPUT_DEB" | grep -E \
        "\.DS_Store|^\._|\.AppleDouble|\.LSOverride|\.Spotlight-V100|\.Trashes" >/dev/null
    then
        echo
        echo "❌ Junk files detected inside $OUTPUT_DEB"
        exit 1
    fi

    echo
    dpkg-deb -f "$OUTPUT_DEB" Package Version Architecture
    echo "Path: /${PREFIX}Applications/${APP_NAME}.app"

    BUILT_DEBS+=("$OUTPUT_DEB")
done

###############################################################################
# Build summary
###############################################################################

echo
echo "======================================================="
echo "                 BUILD SUCCESSFUL"
echo "======================================================="

echo
echo "Application : $APP_NAME"
echo "Package ID  : $PACKAGE_ID"
echo "Version     : $FULL_VERSION"

echo
for DEB in "${BUILT_DEBS[@]}"; do
    echo "$(basename "$DEB")"
    echo "  size   : $(ls -lh "$DEB" | awk '{print $5}')"
    echo "  sha256 : $(shasum -a 256 "$DEB" | awk '{print $1}')"
done

echo
echo "Executable information"
echo "----------------------"
file "$SIGNED_APP/$APP_NAME"
lipo -info "$SIGNED_APP/$APP_NAME" 2>/dev/null || true

echo
echo "Done."
