# Troubleshooting

## Linux installer

**"This script requires root privileges"**
Run with `sudo ./install.sh` (or `sudo ./uninstall.sh`).

**"Unsupported OS"**
Only Debian/Ubuntu (`/etc/debian_version`), Fedora (`/etc/fedora-release`),
and Arch (`/etc/arch-release`) are detected automatically. On anything
else, follow the manual steps in `linux/steps.txt`.

**"Another instance is running. (Lock: /tmp/fr_custom_installer.lock)"**
A previous run didn't exit cleanly. If you're sure nothing is actually
running: `sudo rm -rf /tmp/fr_custom_installer.lock`, then retry.

**Layout doesn't appear after installing**
1. Log out and back in, or reboot (some DEs cache the keyboard layout list
   at session start).
2. Check `linux/logs/install.log` (timestamped) for warnings.
3. On Wayland, `setxkbmap` doesn't apply system-wide -- the installer uses
   DE-specific mechanisms (`gsettings` for GNOME, `kwriteconfig` for KDE,
   `xfconf-query` for XFCE) instead. If your DE isn't one of those three,
   you'll need to add the layout manually via your DE's keyboard settings.
4. Confirm the layout actually registered:
   `grep fr_custom /usr/share/X11/xkb/rules/evdev.xml` (or your layout's
   `xkb_name`).

**KDE: "qdbus" warning during install**
Harmless on Plasma 6, where the old `org.kde.keyboard` D-Bus interface no
longer exists. The layout is still applied via `kwriteconfig6`; the
installer intentionally treats this specific failure as non-fatal.

**Something is badly broken and I just want my keyboard back**
```bash
sudo ./uninstall.sh && sudo reboot
```
This is safe to run even if the install was only partially completed --
every step it takes is individually guarded (checks the target exists
before touching it).

## Core engine / CLI

**"Cannot generate '...': layout has validation errors"**
Run `keyboardforge validate <file.json>` to see exactly which key(s) or
metadata fields are the problem. Common causes: a key with an empty level,
zero keys defined, or an `xkb_name`/`variant` containing spaces or symbols.

**`keyboardforge system-layouts` says "No XKB layout data found"**
Your system doesn't have the `xkb-data` package installed (this provides
`/usr/share/X11/xkb/symbols/` and `/usr/share/X11/xkb/rules/evdev.xml`).
On Debian/Ubuntu: `sudo apt-get install -y xkb-data`. On Fedora:
`sudo dnf install -y xkeyboard-config`. On Arch:
`sudo pacman -S xkeyboard-config`. Alternatively, point
`--symbols-dir`/`--rules-xml` at a copy of this data from elsewhere.

**`import-system` produced far fewer keys than I expected**
Check whether you passed `--no-resolve-includes` -- without it (the
default), `import-system` follows `include` chains recursively to produce
a complete layout; with it, you only get that one variant's own locally
defined keys, which for many real layouts (e.g. British English, German)
is a small fraction of the total. See `docs/cli-manual.md` and
`docs/developer-guide.md` for exactly how this works.

**`import` (not `import-system`) produced fewer keys than the source file
seems to have**
`import` is a plain single/multi-variant XKB text parser with **no**
filesystem access -- it does not follow `include` statements to pull in
keys from other files, it only records them as metadata. If your source
file relies heavily on `include`, use `import-system` instead (which does
resolve them), or manually merge the included file's own keys yourself.
See `docs/developer-guide.md` for the precise, documented parser boundary.

**Import produced a layout missing some keys I know are in the source file
(and it's not an `include` issue)**
The parser handles a specific practical subset of XKB syntax (see
`docs/developer-guide.md`). Multi-group (Group2+) key definitions or
unusual formatting may not be picked up -- treat the import as a starting
point and compare against the source file.

## GUI

**Drag-and-drop doesn't do anything**
Make sure you're dragging from a palette symbol (not a keycap) onto a
keycap, and that a layout is already loaded (New Layout or Load JSON
first).

**My changes disappeared after I loaded a different file**
Loading a new file replaces the whole in-memory layout and its undo
history. Save first if you want to keep the previous one.

**A keycap shows a technical name (like "Cyrillic_ya") instead of a
character**
That symbol isn't in the display table yet -- it still works correctly
(the JSON stores the right value, and it will generate/install fine), it
just doesn't have a nicer character to show. See "The GUI's
keysym-to-character table" in `docs/developer-guide.md` for how to add
one, or open an issue with the symbol name so it can be added.

**I want to import my system's real keyboard layout, but there's no
button for that in the GUI**
This is by design -- the GUI is a static webpage with no filesystem
access, so it can't scan `/usr/share/X11/xkb/` itself. Use the CLI's
`keyboardforge import-system` command to convert it to JSON first, then
**Load JSON** the result here. See `docs/gui-manual.md` section 5.

## Still stuck?

Check `docs/faq.md`, or open an issue describing: which component
(`linux`/`core`/`cli`/`gui`), your distro/DE if relevant, and the exact
command + output.
