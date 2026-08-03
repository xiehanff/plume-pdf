#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skip_build=false

case "${1:-}" in
  "") ;;
  --skip-build) skip_build=true ;;
  *)
    printf 'Usage: %s [--skip-build]\n' "${BASH_SOURCE[0]}" >&2
    exit 2
    ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'macOS DMG packaging must run on macOS\n' >&2
  exit 1
fi

full_version="$(sed -n 's/^version:[[:space:]]*//p' "$repo_root/pubspec.yaml" | head -n 1)"
if [[ -z "$full_version" ]]; then
  printf 'Missing version in pubspec.yaml\n' >&2
  exit 1
fi

app_version="${full_version%%+*}"
app_bundle="$repo_root/build/macos/Build/Products/Release/Plume PDF.app"
release_dir="$repo_root/build/macos/release"
dmg_path="$release_dir/plume-pdf-${app_version}.dmg"

if [[ "$skip_build" == false ]]; then
  fvm flutter build macos --release --verbose
fi

if [[ ! -d "$app_bundle" ]]; then
  printf 'macOS release app not found: %s\n' "$app_bundle" >&2
  printf 'Run fvm flutter build macos --release first.\n' >&2
  exit 1
fi

mkdir -p "$release_dir"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/plume-pdf-dmg.XXXXXX")"
cleanup() {
  rm -rf "$stage_dir"
}
trap cleanup EXIT

ditto "$app_bundle" "$stage_dir/Plume PDF.app"
ln -s /Applications "$stage_dir/Applications"

hdiutil create \
  -volname "Plume PDF" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$dmg_path"

printf 'macOS DMG release package: %s\n' "$dmg_path"
