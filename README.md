<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/logo-dark.svg">
  <img src=".github/logo-light.svg" width="64" height="64" alt="rice">
</picture>

# plasma-setup

The KDE Plasma 6 layer of my setup, independent of the distro: a floating top bar, floating maximized windows, and an Everforest theme with a light/dark switch.

Related repos, all applied by chezmoi from [dotfiles](https://github.com/Aethryl/dotfiles):

- [plasma-widgets](https://github.com/Aethryl/plasma-widgets): claudebar, sysbar and the mural wallpaper rotator
- [wallpapers](https://github.com/Aethryl/wallpapers): the wallpaper collection
- dotfiles: shell, terminal and app configs, plus OS packages

## What's in here

| Path | What it does |
|---|---|
| `shell-override/` | Patched copy of the Plasma desktop shell: floating panels (the top bar and the dock) get the bar's tinted fill, hairline border and rounded corners; the top bar always floats, has a tiny top gap, and reserves only its drawn height.  The lock screen unlocks straight away when PAM succeeds without a prompt (Howdy face unlock), instead of showing the Unlock button. Authentication only starts on real input (key, click, mouse move), so face unlock waits until you touch the lock screen. |
| `systemd/plasma-shell-override.service` | Rebuilds the shell override from the system copy before each plasmashell start, so Plasma updates are picked up. |
| `systemd/plasma-shell-override.path` | Re-runs that rebuild when the system shell files change (e.g. a mid-session `dnf upgrade`). It never restarts plasmashell; do that yourself to load the new copy. |
| `kwin-scripts/floatingwindows` | Insets maximized and quick-tiled (Meta+arrows: halves and quarters) windows by a small gap so they float like the bar; tiles that meet get half a gap each. Apps listed in the script's `exclude` setting (comma-separated window classes, empty by default) stay edge to edge. |
| `kwin-effects/kwin4_effect_geometry_change` | [Geometry Change](https://github.com/peterfajdiga/kwin4_effect_geometry_change) v1.5 by Peter Fajdiga (GPL-3.0, vendored): eases windows into their new size and position when a script or shortcut moves them, such as Meta+arrow tiling and the floating gaps. Runs in the compositor; set to 180 ms. |
| `aurorae/Everforest-Dark`, `aurorae/Everforest-Light` | Window decorations in the [Everforest](https://github.com/sainnhe/everforest) palette. They are recoloured from `aurorae/CatppuccinMocha-Classic`, the [Catppuccin](https://github.com/catppuccin/kde) Mocha Classic decoration (MIT), tweaked to drop the titlebar blur mask and the 1px outer border and to widen the button margins. |
| `lookandfeel/` | Everforest Dark and Light global themes (colours, window decoration, icons). They are set as the defaults for Plasma's own dark-mode switch in Brightness & Color, so that switch and `everforest` do the same thing. |
| `bin/launcher` | `launcher kickoff\|krunner` picks what Meta opens: Kickoff in the dock (restyled: favourites grid, compact list) or KRunner centred like Spotlight. |
| `colorschemes/` | Everforest Dark and Light KDE colour schemes. The widgets take their colours from these. |
| `wallpapers/` | On-palette wallpapers for each mode, also used on the lock screen. |
| `bin/everforest` | `everforest [dark\|light\|toggle\|status]` switches the colour scheme, window decoration, GTK preference and btop theme. It also sets the matching wallpaper, but only while mural rotation is off. The lock screen is left alone. Bound to Meta+Shift+L and also runnable from KRunner ("Toggle light/dark"). ghostty follows on its own with `theme = light:Everforest Light Med,dark:Everforest Dark Hard`. |

`install.sh` also turns off autostart items this setup doesn't use: Discover's tray notifier (the statusbar shows updates), the calendar reminder daemon and Akonadi (no KMail/KOrganizer), KDE's push-notification distributor, Fedora's live-installer helper, the Geoclue demo agent and GNOME's localsearch indexer (Baloo already indexes). Undo one by deleting its file in `~/.config/autostart/`, or `systemctl --user unmask akonadi_control.service` for Akonadi.

## Licence

MIT (see `LICENSE`), except `kwin-effects/kwin4_effect_geometry_change`, which is GPL-3.0 (Peter Fajdiga; licence in its `LICENSE`). The `aurorae/` themes are derived from Catppuccin and carry its MIT notice in their `LICENSE` files.

## Requirements

- Plasma 6 (tested on 6.7.5)
- `kwin-effect-roundcorners` for the rounded corners and outlines

## Install

```sh
./install.sh
systemctl --user restart plasma-plasmashell
```

The clone can live anywhere; `install.sh` points the systemd unit at its real path (default `~/Repos/rice/plasma-setup` is linked as is).

## Undo the shell override

```sh
systemctl --user disable --now plasma-shell-override.service
rm -rf ~/.local/share/plasma/shells/org.kde.plasma.desktop
systemctl --user restart plasma-plasmashell
```
