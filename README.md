# plasma-customizations

My KDE Plasma 6 setup: a floating top bar, floating maximized windows, and a Claude status widget.

## What's in here

| Path | What it does |
|---|---|
| `plasmoids/io.github.aethryl.claudebar` | Panel widget showing herdr agent states (working / blocked / idle) and Claude's 5-hour and weekly limits; click it to open a notch-style dropdown. |
| `shell-override/` | Patched copy of the Plasma desktop shell: the top bar always floats, has a tiny top gap, and reserves only its drawn height. |
| `systemd/plasma-shell-override.service` | Rebuilds the shell override from the system copy before each plasmashell start, so Plasma updates are picked up. |
| `kwin-scripts/floatingwindows` | Insets maximized windows by a small gap so they float like the bar. |
| `panel/add-claudebar.js` | Adds the widget to the top panel (run via `evaluateScript`). |

## Requirements

- Plasma 6 (tested on 6.7.5, Fedora 44)
- herdr on `~/.local/bin/herdr` for agent counts
- `kwin-effect-roundcorners` for the rounded corners and outlines
- Claude Code with a statusline script that writes `rate_limits` to `~/.cache/claude-bar/limits.json`:

  ```python
  def cache_rate_limits(rate_limits):
      if not rate_limits:
          return
      path = os.path.expanduser("~/.cache/claude-bar/limits.json")
      os.makedirs(os.path.dirname(path), exist_ok=True)
      tmp = f"{path}.{os.getpid()}.tmp"
      with open(tmp, "w") as f:
          json.dump({"updated_at": time.time(), "rate_limits": rate_limits}, f)
      os.replace(tmp, path)
  ```

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
