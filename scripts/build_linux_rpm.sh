#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skip_build=false

if [[ "${1:-}" == "--skip-build" ]]; then
  skip_build=true
fi

full_version="$(sed -n 's/^version:[[:space:]]*//p' "$repo_root/pubspec.yaml" | head -n 1)"
if [[ -z "$full_version" ]]; then
  printf 'Missing version in pubspec.yaml\n' >&2
  exit 1
fi

app_version="${full_version%%+*}"
if [[ "$full_version" == *+* ]]; then
  app_release="${full_version##*+}"
else
  app_release=1
fi

bundle_dir="$repo_root/build/linux/x64/release/bundle"
rpm_output_dir="$repo_root/build/linux/x64/release"

if [[ "$skip_build" == false ]]; then
  fvm flutter build linux --release --verbose
fi

if [[ ! -x "$bundle_dir/plume_pdf" ]]; then
  printf 'Linux release bundle not found: %s\n' "$bundle_dir" >&2
  printf 'Run fvm flutter build linux --release first.\n' >&2
  exit 1
fi

if ! command -v rpmbuild >/dev/null 2>&1; then
  printf 'rpmbuild is required to build the RPM package\n' >&2
  exit 1
fi

if ! command -v patchelf >/dev/null 2>&1; then
  printf 'patchelf is required to build the RPM package\n' >&2
  exit 1
fi

rpm_top="$(mktemp -d)"
trap 'rm -rf "$rpm_top"' EXIT
mkdir -p "$rpm_top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

tar -C "$(dirname "$bundle_dir")" \
  -czf "$rpm_top/SOURCES/plume-pdf-bundle.tar.gz" bundle
tar -C "$repo_root/linux/icons" \
  -czf "$rpm_top/SOURCES/plume-pdf-icons.tar.gz" hicolor
cp "$repo_root/linux/com.example.plume_pdf.desktop" \
  "$rpm_top/SOURCES/com.example.plume_pdf.desktop"

# When packaging on Debian/Ubuntu, patchelf may be installed by dpkg rather
# than RPM, so rpmbuild cannot see it in the RPM package database. We verify
# the required executable above and skip only rpmbuild's package-database
# dependency check here.
rpmbuild \
  --nodeps \
  --define "_topdir $rpm_top" \
  --define "app_version $app_version" \
  --define "app_release $app_release" \
  -bb "$repo_root/packaging/plume-pdf.spec"

rpm_artifact="$(find "$rpm_top/RPMS" -type f \
  -name "plume-pdf-${app_version}-${app_release}.*.rpm" -print -quit)"
if [[ -z "$rpm_artifact" ]]; then
  printf 'rpmbuild completed without an RPM artifact\n' >&2
  exit 1
fi

mkdir -p "$rpm_output_dir"
release_rpm="$rpm_output_dir/$(basename "$rpm_artifact")"
cp -f "$rpm_artifact" "$release_rpm"
printf 'RPM release package: %s\n' "$release_rpm"
