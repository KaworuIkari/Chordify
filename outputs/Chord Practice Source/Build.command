#!/bin/zsh
set -euo pipefail
source_dir="${0:A:h}"
output_dir="${source_dir:h}"
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/chord-practice-build.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
app="$output_dir/Chord Practice.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
    xcrun swiftc -O -parse-as-library -target "$arch-apple-macosx13.0" \
        -module-cache-path "$build_dir/ModuleCache" \
        "$source_dir/ChordEngine.swift" "$source_dir/StaffNotation.swift" \
        "$source_dir/StaffView.swift" "$source_dir/ChordPractice.swift" \
        "$source_dir/CircleOfFifthsModel.swift" "$source_dir/CircleOfFifthsView.swift" \
        "$source_dir/ScaleModes.swift" \
        "$source_dir/ChordAudioOptions.swift" "$source_dir/ChordAudioPlayer.swift" "$source_dir/AudioControlsView.swift" \
        "$source_dir/MetronomeModel.swift" "$source_dir/MetronomeView.swift" \
        -o "$build_dir/ChordPractice-$arch"
done
xcrun lipo -create "$build_dir/ChordPractice-arm64" "$build_dir/ChordPractice-x86_64" -output "$app/Contents/MacOS/ChordPractice.new"
mv -f "$app/Contents/MacOS/ChordPractice.new" "$app/Contents/MacOS/ChordPractice"
cp "$source_dir/Info.plist" "$app/Contents/Info.plist"
xcrun swift -module-cache-path "$build_dir/ModuleCache" "$source_dir/MakeIcon.swift" "$build_dir/AppIcon.iconset"
cp "$build_dir/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
echo "Built: $app"
