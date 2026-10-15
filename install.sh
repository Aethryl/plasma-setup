#!/usr/bin/env bash
set -euo pipefail

repo="$(dirname "$(readlink -f "$0")")"
data="${XDG_DATA_HOME:-$HOME/.local/share}"

mkdir -p "$data/plasma/plasmoids" "$data/kwin/scripts" "$data/aurorae/themes"
ln -sfn "$repo/plasmoids/io.github.aethryl.claudebar" "$data/plasma/plasmoids/io.github.aethryl.claudebar"
ln -sfn "$repo/plasmoids/io.github.aethryl.sysbar" "$data/plasma/plasmoids/io.github.aethryl.sysbar"
ln -sfn "$repo/kwin-scripts/floatingwindows" "$data/kwin/scripts/floatingwindows"

theme="$data/aurorae/themes/CatppuccinMocha-Classic"
if [[ -d "$theme" && ! -L "$theme" ]]; then
    mv "$theme" "$theme.bak.$(date +%s)"
fi
ln -sfn "$repo/aurorae/CatppuccinMocha-Classic" "$theme"

"$repo/shell-override/sync.sh"
systemctl --user link "$repo/systemd/plasma-shell-override.service"
systemctl --user enable plasma-shell-override.service

kwriteconfig6 --file kwinrc --group Plugins --key floatingwindowsEnabled true
for key in DisableRoundMaximize DisableOutlineMaximize DisableRoundTile DisableOutlineTile; do
    kwriteconfig6 --file kwinrc --group Effect-shapecorners --key "$key" false
done
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__CatppuccinMocha-Classic
kwriteconfig6 --file kwinrc --group Effect-slidingpopups --key SlideInTime 90
kwriteconfig6 --file kwinrc --group Effect-slidingpopups --key SlideOutTime 110
qdbus-qt6 org.kde.KWin /KWin reconfigure 2>/dev/null || /usr/lib64/qt6/bin/qdbus org.kde.KWin /KWin reconfigure

echo "Restart plasmashell to load the shell override: systemctl --user restart plasma-plasmashell"
