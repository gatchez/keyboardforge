# KeyboardForge Architecture

## Component map

The project's recommended architecture (Core Engine, Layout Parser, Keyboard
Model, Layout Generator, Installation Manager, GUI Module, CLI Module,
Configuration Manager, Packaging Module, Testing Module, Documentation
Module) maps onto this repository as follows:

| Architecture component | Implementation                                   |
|--------------------------|---------------------------------------------------|
| Keyboard Model              | `core/keyboardforge_core/model.py`                    |
| Layout Parser                  | `core/keyboardforge_core/xkb_parser.py`                  |
| System Layout Detection & Import  | `core/keyboardforge_core/system_layouts.py`                |
| Layout Generator                  | `core/keyboardforge_core/xkb_generator.py`                  |
| Core Engine (validation)             | `core/keyboardforge_core/validator.py`                        |
| Installation Manager                    | `linux/install.sh`, `linux/uninstall.sh`, `linux/modules/`      |
| Configuration Manager                       | `linux/modules/common.sh` (detection, locking, logging)            |
| CLI Module                                     | `cli/keyboardforge_cli/`                                             |
| GUI Module                                        | `gui/` (static browser-based visual editor; `keysyms.js` renders actual characters, not keysym names) |
| Packaging Module                                     | `packaging/` (.deb, .rpm, PKGBUILD, pip)                                 |
| Testing Module                                          | `core/tests/`, `cli/tests/`, `linux/test.sh`, `tests/run_all_tests.sh`     |
| Documentation Module                                       | `docs/`                                                                       |

## Data flow

```
  Two ways to get a Layout (Keyboard Model) into KeyboardForge:

  (a) From scratch                (b) From your OS's real, installed layout
  ┌─────────────────────┐          ┌──────────────────────────────────────┐
  │ keyboardforge new     │          │ /usr/share/X11/xkb/symbols/<name>      │
  │ (or GUI "New Layout")   │          │ /usr/share/X11/xkb/rules/evdev.xml       │
  └──────────┬─────────────┘          └───────────────────┬──────────────────┘
             │                                              │ system_layouts.py
             │                                              │ (detects variants,
             │                                              │  resolves `include`
             │                                              │  chains recursively)
             ▼                                              ▼
       ┌────────────────────────────────────────────────────────┐
       │              layouts/*.json  (Keyboard Model)             │
       │   fr_custom is the bundled example and current installer   │
       │   target; the model itself supports other layout names.     │
       └──────────────────────────┬───────────────────────────────────┘
                                    │
                          core/keyboardforge_core
                ┌──────────────────┼───────────────────┐
                │                  │                    │
         validator.py     xkb_generator.py       xkb_parser.py
                │                  │                    │  (also reachable
                │                  ▼                    │   directly via
                │        linux/<xkb_name> (XKB)         │   `keyboardforge
                │        linux/rules (XML)               │   import`, for
                │                  │                     │   round-tripping
                └──────────────────┼─────────────────────┘   your own files)
                                   ▼
                          linux/install.sh
                     (Debian / Fedora / Arch)
                                   │
                                   ▼
                        GNOME / KDE / XFCE
                    (Wayland or X11 aware)
```

The diagram abstracts the generated-file handoff. In the current
implementation, the installer consumes the fixed `fr_custom` symbols
file and rules entry; it does not install every generated `xkb_name`.

Both the CLI (`cli/`) and GUI (`gui/`) are *thin clients* over
`core/keyboardforge_core`: they read and write the same JSON layout model,
with no duplicated layout logic between them. Layouts can be edited and
exported through either workflow. The Linux installer is a separate,
currently single-layout component: it expects the bundled `fr_custom`
symbols file and rules entry. Arbitrary layout names are not yet supported
by the install/uninstall scripts, even though the core can generate them.

## Why JSON as the source of truth?

The original prototype hand-wrote the XKB symbols file and the XML rules
stub directly. That works for one fixed layout, but doesn't scale to "create
entirely new layouts" or "edit individual keys" as required by the
functional requirements. Introducing a small internal JSON model with a
generator/parser pair means:

- The GUI and CLI can both operate on the same structured data instead of
  string-manipulating XKB syntax.
- Layouts can be validated (duplicate keys, missing base level, malformed
  dead keys) *before* they ever touch a real system file.
- Real, OS-installed layouts can be imported with resolvable `include`
  chains followed recursively (see `docs/developer-guide.md`). This makes
  the importer useful for starting a layout from real operating-system
  data rather than only from KeyboardForge's example. The parser remains
  a practical subset of XKB, not a complete grammar implementation.

## Current platform and installation scope

Linux is the current platform under development. The installer supports
Debian/Ubuntu, Fedora, and Arch, and integrates GNOME, KDE Plasma, and
XFCE. It currently installs only the bundled `fr_custom` layout; the
model, CLI, and generator support editing and exporting other layout names,
but install/uninstall support for those names is not implemented yet.
Windows and macOS are deferred until work on the Linux module is complete.

## Coding standards

- **Bash** (`linux/`): `#!/usr/bin/env bash`, `set -E` + `ERR` trap in entry
  points, all system-mutating calls go through `safe_exec()` (never a bare
  command) so failures degrade to a warning instead of crashing, all
  destructive operations are gated behind `check_writable()` and
  `backup_file()`, `--dry-run` must never write to disk.
- **Python** (`core/`, `cli/`): stdlib only for `core/` (no runtime
  dependencies for the engine itself), PEP 8, type hints on public
  functions, one class/responsibility per module, everything importable and
  unit-testable without touching the filesystem outside of a supplied path.
- **JS/HTML/CSS** (`gui/`): no build step, no external CDN dependency
  required to open `index.html` locally, vanilla JS only.
- **Every component ships its own tests**, and `tests/run_all_tests.sh` runs
  all of them from one entry point for CI.
