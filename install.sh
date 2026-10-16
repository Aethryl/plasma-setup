#!/usr/bin/env bash
set -euo pipefail

repo="$(dirname "$(readlink -f "$0")")"
data="${XDG_DATA_HOME:-$HOME/.local/share}"

mkdir -p "$data/kwin/scripts" "$data/aurorae/themes" "$data/color-schemes" \
    "$data/applications" "$HOME/.local/bin"
ln -sfn "$repo/kwin-scripts/floatingwindows" "$data/kwin/scripts/floatingwindows"
mkdir -p "$data/kwin/effects"
ln -sfn "$repo/kwin-effects/kwin4_effect_geometry_change" "$data/kwin/effects/kwin4_effect_geometry_change"

for variant in Dark Light; do
    theme="$data/aurorae/themes/Everforest-$variant"
    if [[ -d "$theme" && ! -L "$theme" ]]; then
        mv "$theme" "$theme.bak.$(date +%s)"
    fi
    ln -sfn "$repo/aurorae/Everforest-$variant" "$theme"
    ln -sfn "$repo/colorschemes/Everforest$variant.colors" "$data/color-schemes/Everforest$variant.colors"
done
mkdir -p "$data/plasma/look-and-feel"
for mode in dark light; do
    ln -sfn "$repo/lookandfeel/io.github.aethryl.everforest-$mode" "$data/plasma/look-and-feel/io.github.aethryl.everforest-$mode"
done
kwriteconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel io.github.aethryl.everforest-dark
kwriteconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel io.github.aethryl.everforest-light
ln -sfn "$repo/bin/everforest" "$HOME/.local/bin/everforest"
ln -sfn "$repo/bin/launcher" "$HOME/.local/bin/launcher"
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
for entry in org.kde.discover.notifier org.kde.kalendarac org.kde.kunifiedpush-distributor liveinst-setup geoclue-demo-agent localsearch-3; do
    printf '[Desktop Entry]\nHidden=true\n' > "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/$entry.desktop"
done
systemctl --user mask akonadi_control.service >/dev/null 2>&1 || true
ln -sfn "$repo/applications/everforest-toggle.desktop" "$data/applications/everforest-toggle.desktop"
kwriteconfig6 --file kglobalshortcutsrc --group services --group everforest-toggle.desktop --key _launch "Meta+Shift+L"

"$repo/shell-override/sync.sh"
systemctl --user link "$repo/systemd/plasma-shell-override.service"
systemctl --user enable plasma-shell-override.service

kwriteconfig6 --file kwinrc --group Plugins --key floatingwindowsEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_geometry_changeEnabled true
kwriteconfig6 --file kwinrc --group Effect-kwin4_effect_geometry_change --key Duration 180
for key in DisableRoundMaximize DisableOutlineMaximize DisableRoundTile DisableOutlineTile; do
    kwriteconfig6 --file kwinrc --group Effect-shapecorners --key "$key" false
done
gap="$(grep -oP 'readConfig\("gap", \K\d+' "$repo/kwin-scripts/floatingwindows/contents/code/main.js")"
grep -oP '^\[Tiling\]\[\K[^]]+\]\[[^]]+(?=\]$)' "${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc" | while IFS= read -r ids; do
    kwriteconfig6 --file kwinrc --group Tiling --group "${ids%%]*}" --group "${ids#*[}" --key padding "$gap"
done
kwriteconfig6 --file kwinrc --group Effect-slidingpopups --key SlideInTime 90
kwriteconfig6 --file kwinrc --group Effect-slidingpopups --key SlideOutTime 110
qdbus-qt6 org.kde.KWin /KWin reconfigure 2>/dev/null || /usr/lib64/qt6/bin/qdbus org.kde.KWin /KWin reconfigure

gdbus call --session -d org.kde.kded6 -o /modules/gtkconfig -m org.kde.GtkConfig.setGtkTheme Breeze >/dev/null
"$repo/bin/everforest" "$("$repo/bin/everforest" status)"

echo "Restart plasmashell to load the shell override: systemctl --user restart plasma-plasmashell"
