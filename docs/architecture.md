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
       │   fr_custom is the bundled example; generated layouts can   │
       │   be installed by name through the CLI and installer.       │
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

The diagram abstracts the generated-file handoff. The installer consumes
the selected generated symbols file and matching rules entry, with
`fr_custom`/`custom` as direct-script defaults. Each generated rules block
is marked and can be removed without restoring an outdated copy of the
shared `evdev.xml`; independent management of all other installation state
for multiple layouts remains in progress.

Both the CLI (`cli/`) and GUI (`gui/`) are *thin clients* over
`core/keyboardforge_core`: they read and write the same JSON layout model,
with no duplicated layout logic between them. Layouts can be edited and
exported through either workflow. The Linux installer is a separate
component, but now accepts generated layout names and variants. The bundled
`fr_custom`/`custom` pair remains the default for direct script use.

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
XFCE. It installs generated layout names and variants, with
`fr_custom`/`custom` as the direct-script default. Independent
multi-layout registration and removal in the shared system rules file
remain outstanding.
Windows and macOS are deferred until work on the Linux module is complete.

### Current Linux installer support matrix

The following describes the branches currently implemented, not a claim
that every distro/desktop combination has been verified in a real session:

| Area | Current implementation |
|---|---|
| Distribution detection | Debian/Ubuntu via `/etc/debian_version`; Fedora via `/etc/fedora-release`; Arch via `/etc/arch-release`. Other distributions use the documented manual path. |
| Distro-level configuration | Debian/Ubuntu edits `/etc/default/keyboard`; Fedora and Arch call `localectl` for the X11 keymap. Fedora may call `dracut`; Arch calls `mkinitcpio` when available. |
| GNOME | Attempts to set the user's input source through `gsettings`. |
| KDE Plasma | Attempts to configure the user's layout using `kwriteconfig5` or `kwriteconfig6`. |
| XFCE on X11 | Attempts to configure `xfconf-query` and apply the layout with `setxkbmap`. |
| XFCE on Wayland | Not automatically configured; the user must apply the layout through desktop settings. |
| Other/undetected desktop environments | System layout files are installed, but desktop input-source setup is manual. |
| Display-server detection | Wayland is detected from `WAYLAND_DISPLAY` or `XDG_SESSION_TYPE`; otherwise the installer assumes X11. |

The scripts do not currently validate every distro/desktop/display-server
combination as a matrix. Those combinations remain a verification task
under the Linux integration checklist.

## Coding standards

- **Bash** (`linux/`): `#!/usr/bin/env bash`, `set -E` + `ERR` trap in entry
  points, external commands go through `safe_exec()` where applicable,
  required failures propagate to the transaction rollback, all
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
