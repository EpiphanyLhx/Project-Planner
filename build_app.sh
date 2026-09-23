#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_dir"

swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_dir/Dist/研途.app"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/ProjectPlanner" "$app_dir/Contents/MacOS/ProjectPlanner"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Assets/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$app_dir"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/研途.app"
cp -R "$app_dir" "$HOME/Applications/研途.app"

echo "$HOME/Applications/研途.app"
