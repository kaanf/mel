#!/bin/sh
# Builds .build/release/Mel-<version>.dmg (DESIGN.md › Distribution):
#   archive → export (Developer ID) → notarize + staple app → DMG → sign, notarize + staple DMG → appcast.xml.
# The build number (CFBundleVersion, what Sparkle compares) is the commit count, so every release from main is higher.
# After notarizing it signs the DMG with the Sparkle EdDSA key from the login Keychain and writes appcast.xml
# at the repo root; commit it after `gh release create v<version>` with the DMG.
#
# Signed release: TEAM_ID=SGWP227GBQ scripts/release.sh
#   Needs "Developer ID Application" for TEAM_ID in the keychain and the notary profile NOTARY_PROFILE
#   (default mel-notary), created once with `xcrun notarytool store-credentials mel-notary`.
#   Without the profile it still signs and verifies the app and DMG, then stops before notarizing.
# Without TEAM_ID it stops after an ad-hoc signed DMG: fine for a local check, Gatekeeper blocks it elsewhere.
set -eu
cd "$(dirname "$0")/.."

OUT=.build/release
ARCHIVE="$OUT/Mel.xcarchive"
APP="$OUT/Mel.app"
NOTARY_PROFILE=${NOTARY_PROFILE:-mel-notary}
VERSION=$(xcodebuild -project Mel.xcodeproj -scheme Mel -configuration Release -showBuildSettings 2>/dev/null |
    awk '$1 == "MARKETING_VERSION" { print $3; exit }')
BUILD=$(git rev-list --count HEAD)
DMG="$OUT/Mel-$VERSION.dmg"

if [ -n "${TEAM_ID:-}" ]; then
    IDENTITY="Developer ID Application"
    CERT=$(security find-identity -v -p codesigning | awk -v id="\"$IDENTITY: " -v team="($TEAM_ID)\"" \
        'index($0, id) && index($0, team) { print $2; exit }')
    [ -n "$CERT" ] || { echo "✗ No \"$IDENTITY: … ($TEAM_ID)\" certificate in the keychain." >&2; exit 1; }
    # Errors out without the profile; with it, a quick authenticated call.
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        NOTARIZE=1
    else
        NOTARIZE=0
        echo "! Notary profile \"$NOTARY_PROFILE\" not found: signing only, no notarization." >&2
    fi
fi

rm -rf "$OUT"
mkdir -p "$OUT"

notarize() {  # stapler fails unless notarization was accepted, so `set -e` stops a rejected build
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$2"
}

echo "→ archive $VERSION ($BUILD)"
if [ -z "${TEAM_ID:-}" ]; then
    xcodebuild archive -project Mel.xcodeproj -scheme Mel -configuration Release \
        -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -derivedDataPath .build/DerivedData \
        CURRENT_PROJECT_VERSION="$BUILD" \
        CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= -quiet
    ditto "$ARCHIVE/Products/Applications/Mel.app" "$APP"
else
    xcodebuild archive -project Mel.xcodeproj -scheme Mel -configuration Release \
        -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -derivedDataPath .build/DerivedData \
        CURRENT_PROJECT_VERSION="$BUILD" \
        CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM_ID" -quiet

    echo "→ export (Developer ID)"
    cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>$IDENTITY</string>
</dict>
</plist>
EOF
    xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT" \
        -exportOptionsPlist "$OUT/ExportOptions.plist" -quiet
    codesign --verify --deep --strict --verbose=2 "$APP"

    if [ "$NOTARIZE" = 1 ]; then
        echo "→ notarize app"
        ditto -c -k --keepParent "$APP" "$OUT/Mel.zip"
        notarize "$OUT/Mel.zip" "$APP"
        spctl --assess --type execute -vv "$APP"
    fi
fi

echo "→ dmg"
mkdir "$OUT/dmg"
ditto "$APP" "$OUT/dmg/Mel.app"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -volname Mel -srcfolder "$OUT/dmg" -fs APFS -format ULFO -ov "$DMG" -quiet

if [ -n "${TEAM_ID:-}" ]; then
    codesign --sign "$CERT" --timestamp "$DMG"
    codesign --verify --strict --verbose=2 "$DMG"
    if [ "$NOTARIZE" = 0 ]; then
        echo "✗ Signed but not notarized: $DMG" >&2
        echo "  Create the profile once: xcrun notarytool store-credentials $NOTARY_PROFILE" >&2
        exit 1
    fi
    echo "→ notarize dmg"
    notarize "$DMG" "$DMG"
    spctl --assess --type open --context context:primary-signature -vv "$DMG"

    echo "→ appcast.xml"
    # sign_update ships with the Sparkle package pinned in the project; prints sparkle:edSignature="…" length="…"
    SIGNATURE=$(.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update "$DMG")
    cat > appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Mel</title>
        <item>
            <title>$VERSION</title>
            <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
            <enclosure url="https://github.com/kaanf/mel/releases/download/v$VERSION/Mel-$VERSION.dmg" type="application/octet-stream" $SIGNATURE/>
        </item>
    </channel>
</rss>
EOF
    echo "✓ appcast.xml (build $BUILD)"
fi

echo "✓ $DMG"
