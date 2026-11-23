#!/bin/sh
# Builds .build/release/Mel-<version>.dmg (DESIGN.md › Distribution):
#   archive → export (Developer ID) → notarize + staple app → DMG → sign, notarize + staple DMG.
#
# Signed release: TEAM_ID=<team> NOTARY_PROFILE=<profile> scripts/release.sh
#   NOTARY_PROFILE is a keychain profile from `xcrun notarytool store-credentials`.
# Without TEAM_ID it stops after an ad-hoc signed DMG: fine for a local check, Gatekeeper blocks it elsewhere.
set -eu
cd "$(dirname "$0")/.."

OUT=.build/release
ARCHIVE="$OUT/Mel.xcarchive"
VERSION=$(xcodebuild -project Mel.xcodeproj -scheme Mel -configuration Release -showBuildSettings 2>/dev/null |
    awk '$1 == "MARKETING_VERSION" { print $3; exit }')
DMG="$OUT/Mel-$VERSION.dmg"

rm -rf "$OUT"
mkdir -p "$OUT"

notarize() {  # stapler fails unless notarization was accepted, so `set -e` stops a rejected build
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

echo "→ archive $VERSION"
if [ -z "${TEAM_ID:-}" ]; then
    xcodebuild archive -project Mel.xcodeproj -scheme Mel -configuration Release \
        -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -derivedDataPath .build/DerivedData \
        CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= -quiet
    ditto "$ARCHIVE/Products/Applications/Mel.app" "$OUT/Mel.app"
else
    : "${NOTARY_PROFILE:?set NOTARY_PROFILE (xcrun notarytool store-credentials)}"
    xcodebuild archive -project Mel.xcodeproj -scheme Mel -configuration Release \
        -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -derivedDataPath .build/DerivedData \
        DEVELOPMENT_TEAM="$TEAM_ID" -quiet

    echo "→ export (Developer ID)"
    cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
EOF
    xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT" \
        -exportOptionsPlist "$OUT/ExportOptions.plist" -quiet

    echo "→ notarize app"
    ditto -c -k --keepParent "$OUT/Mel.app" "$OUT/Mel.zip"
    notarize "$OUT/Mel.zip"
    xcrun stapler staple "$OUT/Mel.app"
fi

echo "→ dmg"
mkdir "$OUT/dmg"
ditto "$OUT/Mel.app" "$OUT/dmg/Mel.app"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -volname Mel -srcfolder "$OUT/dmg" -fs APFS -format ULFO -ov "$DMG" -quiet

if [ -n "${TEAM_ID:-}" ]; then
    echo "→ notarize dmg"
    codesign --sign "Developer ID Application" --timestamp "$DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
fi

echo "✓ $DMG"
