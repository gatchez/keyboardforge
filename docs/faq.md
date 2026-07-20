# FAQ

**Does KeyboardForge replace my system's default keyboard layouts?**
No. It adds a new layout (with its own `xkb_name`) alongside whatever's
already installed. Uninstalling removes only what KeyboardForge added and
restores your prior system configuration from backup.

**Do I need the GUI, or is the CLI enough?**
Either is enough on its own -- they operate on the same JSON layout files,
so you can freely mix them (e.g. sketch a layout in the GUI, then script
bulk edits with the CLI).

**Is `layouts/fr_custom.json` required, or specific to how the project works?**
Neither -- it's a working example/seed layout bundled so every tool has
something real to load out of the box. Nothing in `core/`, `cli/`, or
`gui/` treats it specially; delete it, ignore it, or replace it with your
own layout(s) freely. See `docs/user-guide.md` section 7.

**Can I start from my keyboard's actual, real-world layout instead of
building one from nothing?**
Yes -- this is a first-class feature, not an afterthought. Run
`keyboardforge system-layouts` to see every layout your OS has installed,
then `keyboardforge import-system <name> out.json --variant <variant>` to
convert any of them (including all their variants -- AZERTY, Dvorak,
Bepo, and so on) into a fully-populated KeyboardForge layout JSON, ready
to customize. See `docs/cli-manual.md` and `docs/user-guide.md` section 1.

**What's the difference between `keyboardforge import` and
`keyboardforge import-system`?**
`import-system` is for your **operating system's real, installed**
layouts -- it knows where they live, resolves the `include` chains many
of them rely on, and pulls in official descriptions/language metadata.
`import` is a simpler, filesystem-unaware parser for a symbols file +
rules file you hand it directly (e.g. KeyboardForge's own previously
generated output) -- see `docs/cli-manual.md` for the full distinction.

**Why does the GUI show characters (like `&`) instead of symbol names
(like `ampersand`) on the keycaps?**
So the visual editor reads like an actual keyboard, matching what's
printed on a real keycap -- you shouldn't need to know XKB's internal
naming scheme just to look at a layout. The underlying JSON still stores
the technical name (`ampersand`), which is what you type into the CLI or
the GUI's edit fields; only the *keycap display* is translated to a
character. See `docs/user-guide.md` section 4 and `docs/gui-manual.md`
section 3.

**Why JSON instead of editing XKB files directly?**
So the GUI and CLI can share one validated data model instead of each
re-implementing XKB string parsing/generation. See "Why JSON as the source
of truth?" in `docs/architecture.md`.

**Can I still hand-write an XKB symbols file if I want to?**
Yes -- `keyboardforge import` converts a hand-written XKB symbols file (plus
its rules XML stub) into the JSON model, so you can start there and finish
in KeyboardForge, or vice versa.

**Does this work on Wayland?**
Yes. The Linux installer detects Wayland vs X11 and uses DE-specific
mechanisms (GNOME `gsettings`, KDE `kwriteconfig`, XFCE `xfconf-query`)
rather than the X11-only `setxkbmap` when on Wayland.

**Which desktop environments are supported?**
GNOME, KDE Plasma (5 and 6), and XFCE are auto-configured. Others fall back
to a warning telling you to add the layout manually via your DE's keyboard
settings -- the layout itself is still correctly installed at the system
level either way.

**Is Windows supported?**
Not yet, and intentionally so -- see "Out of Scope (Current Release)" in
the project's scope document. Windows work requires explicit authorization
before it begins and will live in an isolated `windows/` component when it
does.

**Is macOS supported?**
Not currently; it's listed under Future Scope.

**What happens if I install, then edit the layout, then install again?**
The installer detects the previously-installed version (via a small
version marker file) and logs whether it's reinstalling the same version or
upgrading -- either way, it safely re-backs-up and re-injects rather than
duplicating entries.

**Can I have multiple KeyboardForge layouts installed at once?**
The current `linux/install.sh` is wired to one bundled layout
(`fr_custom`/`rules`) per install run. Installing a second layout means
running the installer again with different generated files in `linux/` --
multi-layout management in a single run is tracked as future work (see
`docs/architecture.md`'s design principles and the project roadmap's
Future Scope, e.g. "Multiple keyboard profile management").

**Where are the tests?**
`core/tests/` (including real-system-data tests in
`test_xkb_parser_real_files.py` and `test_system_layouts.py`), `cli/tests/`,
`linux/test.sh`, `gui/test_logic.js` + `gui/test_keysyms.js` +
`gui/smoke_test.js`, and `tests/test_end_to_end.sh` for the full pipeline.
Run everything with `./tests/run_all_tests.sh` or `make test`.
