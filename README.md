# plasma-customizations

My KDE Plasma 6 setup: a floating top bar, floating maximized windows, and a Claude status widget.

## What's in here

| Path | What it does |
|---|---|
| `plasmoids/io.github.aethryl.claudebar` | Panel widget showing herdr agent states (working / blocked / idle) and Claude's 5-hour and weekly limits; click it to open a notch-style dropdown. |
| `plasmoids/io.github.aethryl.sysbar` | Compact CPU / RAM / GPU / network meters for the top bar; click it for a notch dropdown with history graphs, per-core load and top processes. |
| `shell-override/` | Patched copy of the Plasma desktop shell: the top bar always floats, has a tiny top gap, and reserves only its drawn height. |
| `systemd/plasma-shell-override.service` | Rebuilds the shell override from the system copy before each plasmashell start, so Plasma updates are picked up. |
| `kwin-scripts/floatingwindows` | Insets maximized windows by a small gap so they float like the bar. |
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
  -m org.kde.PlasmaShell.evaluateScript "$(cat panel/add-claudebar.js)"
```

The widget is appended at the end of the panel; drag it between the two spacers in edit mode.

## Undo the shell override

```sh
systemctl --user disable --now plasma-shell-override.service
rm -rf ~/.local/share/plasma/shells/org.kde.plasma.desktop
systemctl --user restart plasma-plasmashell
```
