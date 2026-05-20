#!/bin/bash
#
# release.sh — one-shot release for F1Widget.
#
# Usage:
#   ./scripts/release.sh <marketing-version> [build-number]
#
# Example:
#   ./scripts/release.sh 1.2
#   ./scripts/release.sh 1.3 4
#
# Steps:
#   1. Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION via agvtool.
#   2. Clean + build Release.
#   3. Reinstall to /Applications and rebuild F1Widget.dmg.
#   4. Sign the DMG with Sparkle's sign_update (EdDSA).
#   5. Insert a new <item> at the top of docs/appcast.xml.
#   6. Commit, tag vX.Y, push.
#   7. Print the link to create the GitHub Release.

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <marketing-version> [build-number]"
    echo "Example: $0 1.2"
    exit 1
fi

VERSION="$1"
BUILD="${2:-$(date +%s)}"   # default: epoch as build number, monotonic

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
APP_BUILD="$(ls -d "$DERIVED"/F1Widget-*/Build/Products/Release/F1Widget.app 2>/dev/null | head -1)"
SIGN_UPDATE="$(ls "$DERIVED"/F1Widget-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update 2>/dev/null | head -1)"

if [ -z "$SIGN_UPDATE" ]; then
    echo "❌ Could not find sign_update. Build the project once in Xcode first."
    exit 1
fi

echo "▶︎ Bumping version to $VERSION (build $BUILD)"
PBX="F1Widget.xcodeproj/project.pbxproj"
# Replace MARKETING_VERSION = X.Y; and CURRENT_PROJECT_VERSION = N; lines.
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g" "$PBX"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PBX"

echo "▶︎ Building Release"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
xcodebuild -project F1Widget.xcodeproj -scheme F1Widget -configuration Release \
    -derivedDataPath "$DERIVED"/F1Widget-release build > /tmp/f1widget-build.log 2>&1 || {
    echo "❌ Build failed. Tail of log:"
    tail -30 /tmp/f1widget-build.log
    exit 1
}

NEW_APP="$DERIVED/F1Widget-release/Build/Products/Release/F1Widget.app"
if [ ! -d "$NEW_APP" ]; then
    echo "❌ Build did not produce $NEW_APP"
    exit 1
fi

echo "▶︎ Installing to /Applications"
rm -rf /Applications/F1Widget.app
cp -R "$NEW_APP" /Applications/

echo "▶︎ Packaging F1Widget.dmg"
STAGING="$(mktemp -d)"
cp -R /Applications/F1Widget.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f F1Widget.dmg
hdiutil create -volname "F1Widget" -srcfolder "$STAGING" -ov -format UDZO F1Widget.dmg > /dev/null
rm -rf "$STAGING"
DMG_SIZE="$(stat -f "%z" F1Widget.dmg)"

echo "▶︎ Signing DMG with EdDSA"
SIG_LINE="$("$SIGN_UPDATE" F1Widget.dmg)"
SIGNATURE="$(echo "$SIG_LINE" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
if [ -z "$SIGNATURE" ]; then
    echo "❌ Could not parse signature from sign_update output: $SIG_LINE"
    exit 1
fi

PUBDATE="$(LC_TIME=en_US.UTF-8 date "+%a, %d %b %Y %H:%M:%S %z")"

echo "▶︎ Updating docs/appcast.xml"
# Insert a new <item> right after the opening <channel> block's metadata.
ENTRY=$(cat <<EOF
        <item>
            <title>F1Widget $VERSION</title>
            <pubDate>$PUBDATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>26.3</sparkle:minimumSystemVersion>
            <description><![CDATA[<h3>F1Widget $VERSION</h3><p>See the <a href="https://github.com/tuanle03/F1Widget/releases/tag/v$VERSION">release notes</a> on GitHub.</p>]]></description>
            <enclosure
                url="https://github.com/tuanle03/F1Widget/releases/download/v$VERSION/F1Widget.dmg"
                sparkle:edSignature="$SIGNATURE"
                length="$DMG_SIZE"
                type="application/octet-stream" />
        </item>
EOF
)

# Use Python to insert. Pass via env vars so the bash heredoc doesn't try to
# interpolate XML payload (which contains quotes, slashes, etc.).
ENTRY="$ENTRY" VERSION="$VERSION" python3 - <<'PYEOF'
import os
entry = os.environ["ENTRY"]
version = os.environ["VERSION"]
path = "docs/appcast.xml"
text = open(path).read()
marker = "<description>Latest releases of F1Widget for macOS</description>"
needle = marker + "\n        <language>en</language>\n"
replacement = needle + "\n" + entry + "\n"
if needle not in text:
    raise SystemExit("Marker not found in appcast.xml; please edit manually.")
text = text.replace(needle, replacement, 1)
open(path, "w").write(text)
print(f"Inserted entry for {version}")
PYEOF

echo "▶︎ Committing and tagging"
git add F1Widget.xcodeproj/project.pbxproj F1Widget.dmg docs/appcast.xml F1Widget/Info.plist 2>/dev/null || true
git commit -m "Release v$VERSION" || true
git tag -fa "v$VERSION" -m "F1Widget v$VERSION"

echo
echo "✅ Done."
echo "Next:"
echo "   git push && git push --tags"
echo "   Then open https://github.com/tuanle03/F1Widget/releases/new?tag=v$VERSION"
echo "   Upload F1Widget.dmg as a release asset and publish."
