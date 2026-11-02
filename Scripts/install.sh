#!/bin/zsh
# Builds ScaleStack and installs it in /Applications, which is what makes macOS
#   - open .ssm files in ScaleStack when they are double-clicked,
#   - show each .ssm file's picture as its icon in Finder and on the Desktop,
#   - preview .ssm files with Quick Look (space bar).
# Run it again after changing the code.
set -euo pipefail

PROJECT="${0:A:h:h}"
BUILD="$PROJECT/build/DerivedData"
PRODUCT="$BUILD/Build/Products/Release/ScaleStack.app"
DESTINATION="/Applications/ScaleStack.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Building ScaleStack (Release)…"
xcodebuild -project "$PROJECT/ScaleStack.xcodeproj" -scheme ScaleStack -configuration Release \
    -derivedDataPath "$BUILD" build -quiet

# Quit a running copy so its files can be replaced.
osascript -e 'tell application id "com.scalestack.ScaleStack" to quit' >/dev/null 2>&1 || true

echo "Installing to $DESTINATION…"
rm -rf "$DESTINATION"
ditto "$PRODUCT" "$DESTINATION"

# Make the installed copy the only one LaunchServices knows. Build products left registered
# would compete with it for .ssm files and for the Quick Look extensions.
for configuration in Debug Release; do
    "$LSREGISTER" -u "$BUILD/Build/Products/$configuration/ScaleStack.app" >/dev/null 2>&1 || true
done
"$LSREGISTER" -f -R "$DESTINATION"

# The app used to be called PixelVault. Its copy would keep claiming .pixv files and run its
# own Quick Look extensions, so it goes once ScaleStack is in place.
LEGACY="/Applications/PixelVault.app"
if [[ -d "$LEGACY" ]] && [[ "$(defaults read "$LEGACY/Contents/Info" CFBundleIdentifier 2>/dev/null)" == "com.pixelvault.PixelVault" ]]; then
    echo "Removing the old PixelVault app…"
    "$LSREGISTER" -u "$LEGACY" >/dev/null 2>&1 || true
    rm -rf "$LEGACY"
fi

# Enable the Quick Look extensions and drop thumbnails cached before they existed.
pluginkit -e use -i com.scalestack.ScaleStack.Thumbnail >/dev/null 2>&1 || true
pluginkit -e use -i com.scalestack.ScaleStack.Preview >/dev/null 2>&1 || true
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true

echo "Done. Double-click any .ssm file to open it in ScaleStack."
