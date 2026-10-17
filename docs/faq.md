# FAQ

**Does KeyboardForge replace my system's default keyboard layouts?**
No. The installer adds the selected layout alongside the system's existing
layouts. Uninstalling restores backed-up system configuration.

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
import a variant into JSON and customize it. Include resolution is
best-effort, and the XKB parser supports a subset of the grammar, so
inspect the imported result for omissions. See `docs/cli-manual.md` and
`docs/user-guide.md` section 1.

**What's the difference between `keyboardforge import` and
`keyboardforge import-system`?**
`import-system` is for your **operating system's real, installed**
layouts -- it knows where they live, attempts to resolve their `include`
chains, and pulls in available descriptions/language metadata.
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
The installer detects Wayland. GNOME and KDE Plasma configuration use
their desktop-specific settings tools; XFCE on Wayland is not automatically
configured and requires manual setup. See the support matrix in
`docs/architecture.md`.

**Which desktop environments are supported?**
The installer attempts automatic configuration for GNOME, KDE Plasma
(through `kwriteconfig5`/`kwriteconfig6`), and XFCE on X11. XFCE on Wayland
and other/undetected desktop environments require manual input-source
configuration. See the support matrix in `docs/architecture.md`.

**Is Windows supported?**
Not yet. Windows work is deferred until the Linux module is complete.

**Is macOS supported?**
Not yet. macOS work is deferred until the Linux module is complete.

**What happens if I install, then edit the layout, then install again?**
The installer detects the previously-installed version (via a small
version marker file) and logs whether it's reinstalling the same version or
upgrading -- either way, it safely re-backs-up and re-injects rather than
duplicating entries.

**Can I install any layout I create or import?**
Yes. `keyboardforge install <layout.json>` generates and installs the
layout's own XKB symbols and variant, provided it passes validation and the
target name does not conflict with an unmanaged system layout. Direct
`linux/install.sh` use still defaults to `fr_custom`/`custom`; use
`--layout-name` and `--variant` for a different generated layout.

**Can I have multiple KeyboardForge layouts installed at once?**
Not safely yet. Independent registration and removal of each layout in the
shared system rules file is still in progress.

**Where are the tests?**
`core/tests/` (including real-system-data tests in
`test_xkb_parser_real_files.py` and `test_system_layouts.py`), `cli/tests/`,
`linux/test.sh`, `gui/test_logic.js` + `gui/test_keysyms.js` +
`gui/smoke_test.js`, and `tests/test_end_to_end.sh` for the full pipeline.
Run everything with `./tests/run_all_tests.sh` or `make test`.
