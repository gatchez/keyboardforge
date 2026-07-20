# KeyboardForge

**KeyboardForge** is a cross-platform keyboard layout customization framework: a
future replacement for Microsoft's Keyboard Layout Creator (MSKLC), starting
on Linux.

> Renamed from "FR_CUSTOM Layout Installer Framework" — the Linux installer
> that shipped in the earlier prototype now lives in `linux/` as one
> component of the larger KeyboardForge architecture.

## What it actually does

- **Build a keyboard layout from scratch**, or **import one of your
  operating system's own real, installed layouts** (its actual `us`,
  `fr`, `de`, and 100+ others, including every variant each one ships --
  AZERTY, Dvorak, Bepo, and so on) and customize it from there. Import
  correctly resolves the `include` chains many real layouts rely on, so
  it comes in complete rather than partially empty.
- **Edit visually**, in a zero-install, zero-dependency browser GUI that
  shows the actual character each key produces (not XKB's internal
  technical name), or **edit via a scriptable CLI**, or **both** -- they
  share the exact same underlying layout files.
- **Install it for real** on Debian/Ubuntu, Fedora, or Arch Linux, with
  automatic GNOME/KDE Plasma/XFCE and Wayland/X11 configuration, and a
  clean, tested uninstall path.

`layouts/fr_custom.json` (a customized French layout) ships as a working
example so every tool above has something real to load out of the box --
it is not the point of the project and is not treated specially anywhere
in the code. See `docs/user-guide.md` section 7.

## Project status (roadmap phases)

| Phase | Name                        | Status        | Zip                                   |
|-------|------------------------------|---------------|-----------------------------------------|
| 1     | Project Foundation            | ✅ Complete    | `keyboardforge_phase1_foundation.zip`     |
| 2     | Core Keyboard Engine            | ✅ Complete    | `keyboardforge_phase2_core_engine.zip`      |
| 3     | Linux Integration                 | ✅ Complete    | `keyboardforge_phase3_linux_integration.zip` |
| 4     | Command-Line Interface (CLI)        | ✅ Complete    | `keyboardforge_phase4_cli.zip`                |
| 5     | Graphical User Interface (GUI)        | ✅ Complete    | `keyboardforge_phase5_gui.zip`                  |
| 6     | Packaging & Distribution                | ✅ Complete    | `keyboardforge_phase6_packaging.zip`              |
| 7     | Documentation & Quality Assurance         | ✅ Complete    | `keyboardforge_phase7_docs_qa.zip`                  |
| 8     | Windows Keyboard Customization               | ⏸ **Deferred** | not implemented                                       |

Each phase's zip is **cumulative** — it contains everything from all prior
phases plus that phase's new work, so any zip can be unpacked and used
standalone as a snapshot of the project at that point.

Phase 8 (Windows) is intentionally **not implemented**. Per the project's own
scope document, Windows support "shall remain isolated from the Linux
implementation until development begins" and requires explicit authorization
before work starts. This has not been given, so Phase 8 is skipped rather
than assumed.

## Directory layout

```
keyboardforge/
├── docs/            Architecture, guides, manuals, FAQ, changelog (Phase 7)
├── core/            keyboardforge_core: layout model, parser, generator, validator (Phase 2)
├── layouts/         JSON layout definitions -- the source of truth for each layout (Phase 2/3)
├── tools/           generate_layout.py: JSON -> XKB build step (Phase 3)
├── linux/           Linux installer/uninstaller (Debian, Fedora, Arch) (Phase 3)
├── cli/             keyboardforge_cli: the `keyboardforge` command (Phase 4)
├── gui/             Static browser-based visual layout editor (Phase 5)
├── packaging/       .deb / .rpm / PKGBUILD / pip packaging templates (Phase 6)
└── tests/           Top-level test runner tying all component tests together
```

## Quick start (current capabilities)

```bash
# 1. Validate everything (core engine tests, linux installer tests, CLI/GUI tests)
./tests/run_all_tests.sh

# 2. See what keyboard layouts your OS already has installed
cd cli && python3 -m keyboardforge_cli system-layouts

# 3. Import one of them (fully resolved, including its `include` chain) as a
#    starting point -- or skip this and use layouts/fr_custom.json as an example
python3 -m keyboardforge_cli import-system fr ../layouts/my_french.json --variant azerty

# 4. Install it on Linux (Debian, Fedora, or Arch)
python3 -m keyboardforge_cli install ../layouts/my_french.json --dry-run   # preview first
python3 -m keyboardforge_cli install ../layouts/my_french.json             # then for real
```

See `docs/installation-guide.md`, `docs/user-guide.md`, `docs/cli-manual.md`,
and `docs/gui-manual.md` for details on each component. See
`GIT_WORKFLOW.md` for a complete, phase-by-phase guide to committing and
pushing this project to your own GitHub repository.

## Design principles

- **Cross-platform first:** a common core (`core/`) with platform-specific
  adapters (`linux/`, future `windows/`).
- **Single source of truth:** every layout is defined once as JSON in
  `layouts/`. The XKB symbol file and rules XML consumed by the Linux
  installer are *generated artifacts*, not hand-maintained duplicates.
- **Self-contained distribution:** the Linux installer auto-installs its own
  small dependency list (`libxml2`/`xmllint`) rather than assuming it's
  present.
- **Reliability:** every generated layout is validated before it can be
  installed.
