# plasma-customizations

My KDE Plasma 6 setup: a floating top bar, floating maximized windows, a Claude status widget, and an Everforest theme with a light/dark switch.

## What's in here

| Path | What it does |
|---|---|
| `plasmoids/io.github.aethryl.claudebar` | Panel widget showing herdr agent states (working / blocked / idle) and Claude's 5-hour and weekly limits; click it to open a notch-style dropdown. |
| `plasmoids/io.github.aethryl.sysbar` | Compact CPU / RAM / GPU / network meters for the top bar; click it for a notch dropdown with history graphs, per-core load and top processes. |
| `shell-override/` | Patched copy of the Plasma desktop shell: the top bar always floats, has a tiny top gap, and reserves only its drawn height. |
| `systemd/plasma-shell-override.service` | Rebuilds the shell override from the system copy before each plasmashell start, so Plasma updates are picked up. |
| `kwin-scripts/floatingwindows` | Insets maximized windows by a small gap so they float like the bar. |
| `aurorae/Everforest-Dark`, `aurorae/Everforest-Light` | Window decorations in the [Everforest](https://github.com/sainnhe/everforest) palette. They are recoloured from `aurorae/CatppuccinMocha-Classic`, the [Catppuccin](https://github.com/catppuccin/kde) Mocha Classic decoration (MIT), tweaked to drop the titlebar blur mask and the 1px outer border and to widen the button margins. |
| `plasmoids/io.github.aethryl.mural` | Top-bar wallpaper rotator. Click it for a dropdown with the current wallpaper, Next, Remove from rotation, Delete (moves the file to the trash), a choice between all collections or a single one, and the rotation interval. |
| `bin/mural` | Backend for mural. `mural fetch` downloads everything in `wallpapers/collection.json` to `~/Pictures/Wallpapers/<collection>/`. Other commands: `next`, `collection <name\|all>`, `interval <min>`, `exclude`, `include <id>`, `delete`, `on\|off`, `status`. Any image dropped into a collection folder joins the rotation. |
| `wallpapers/collection.json` | Manifest of the wallpaper collection: source, page and licence for each image. The images themselves are not in git. |
| `lookandfeel/` | Everforest Dark and Light global themes (colours, window decoration, icons). They are set as the defaults for Plasma's own dark-mode switch in Brightness & Color, so that switch and `everforest` do the same thing. |
| `colorschemes/` | Everforest Dark and Light KDE colour schemes. The widgets take their colours from these. |
| `wallpapers/` | On-palette wallpapers for each mode, also used on the lock screen. |
| `bin/everforest` | `everforest [dark\|light\|toggle\|status]` switches the colour scheme, window decoration, GTK preference and btop theme. It also sets the matching wallpaper, but only while mural rotation is off. The lock screen is left alone. Bound to Meta+Shift+L and also runnable from KRunner ("Toggle light/dark"). ghostty follows on its own with `theme = light:Everforest Light Med,dark:Everforest Dark Hard`. |
| `shell/starship.toml` | Starship prompt in ANSI colours, so it follows the terminal theme in both modes. |
| `shell/zshrc-snippet.zsh` | fastfetch once per login and the starship init. Paste it into `~/.zshrc` in place of the p10k blocks. Shell config will move to the dotfiles repo later. |
| `panel/add-claudebar.js` | Adds the widget to the top panel (run via `evaluateScript`). |

## Requirements

- Plasma 6 (tested on 6.7.5, Fedora 44)
- herdr on `~/.local/bin/herdr` for agent counts
- `kwin-effect-roundcorners` for the rounded corners and outlines
- Claude Code with a statusline script that merges `rate_limits` into `~/.cache/claude-bar/limits.json`.
  Every open session runs the statusline with its own last-known snapshot, so the writer must merge per
  window instead of overwriting: keep the higher `used_percentage` for the same `resets_at`, take a later
  `resets_at` as a new window, and never drop a window a snapshot omits. Take a file lock around the
  read-merge-write. Reference implementation: `cache_rate_limits` in `~/.claude/statusline.py`.

## Install

```sh
./install.sh
systemctl --user restart plasma-plasmashell
gdbus call --session -d org.kde.plasmashell -o /PlasmaShell \
  -m org.kde.PlasmaShell.evaluateScript "$(cat panel/add-claudebar.js panel/add-mural.js)"
```

The widgets are added at the end of the panel; in edit mode, drag them into the order sysbar, claudebar, mural, system tray. Claudebar fills the free space and centres itself on the screen, so the panel needs no spacers.

## Undo the shell override

```sh
systemctl --user disable --now plasma-shell-override.service
rm -rf ~/.local/share/plasma/shells/org.kde.plasma.desktop
systemctl --user restart plasma-plasmashell
```
