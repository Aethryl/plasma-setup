#!/usr/bin/env bash
# Rebuild the local shell override from the system copy plus patches/.
set -euo pipefail

src=/usr/share/plasma/shells/org.kde.plasma.desktop
dst="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/shells/org.kde.plasma.desktop"
patches="$(dirname "$(readlink -f "$0")")/patches"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -a "$src/." "$tmp/"

for patch in "$patches"/*.patch; do
    patch --quiet --forward -p1 -d "$tmp" < "$patch"
done

mkdir -p "$(dirname "$dst")"
rm -rf "$dst"
mv "$tmp" "$dst"
trap - EXIT
