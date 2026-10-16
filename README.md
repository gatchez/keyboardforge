# KeyboardForge

**KeyboardForge** is a Linux keyboard-layout customization framework and the
Linux-first foundation for a broader project inspired by Microsoft's Keyboard
Layout Creator (MSKLC).

> Renamed from "FR_CUSTOM Layout Installer Framework" — the Linux installer
> that shipped in the earlier prototype now lives in `linux/` as one
> component of the larger KeyboardForge architecture.

## What it actually does

- **Build a keyboard layout from scratch**, or **import an operating
  system's installed XKB layout** (such as `us`, `fr`, or `de`) and
  customize it from there. The importer resolves supported `include`
  chains, but the XKB parser handles a documented subset of the grammar;
  inspect imported results before relying on them as complete definitions.
- **Edit visually**, in a zero-install, zero-dependency browser GUI that
  shows the actual character each key produces (not XKB's internal
  technical name), or **edit via a scriptable CLI**, or **both** -- they
  share the exact same underlying layout files.
- **Install the bundled `fr_custom` layout** on Debian/Ubuntu, Fedora, or
  Arch Linux, with automatic GNOME/KDE Plasma/XFCE and Wayland/X11
  configuration, and a tested uninstall path. The installer is still
  hard-wired to this one layout; installing arbitrary layout names is not
  supported yet.

`layouts/fr_custom.json` (a customized French layout) ships as a working
example so every tool above has something real to load out of the box.
The core, CLI, and GUI handle it as an ordinary layout; the current Linux
installer uses it as its one supported install target. See
`docs/user-guide.md` section 7.

## Project status (roadmap phases)

| Phase | Name                        | Status        | Zip                                   |
|-------|------------------------------|---------------|-----------------------------------------|
| 1     | Project Foundation            | ✅ Complete    | `keyboardforge_phase1_foundation.zip`     |
| 2     | Core Keyboard Engine            | ✅ Complete    | `keyboardforge_phase2_core_engine.zip`      |
| 3     | Linux Integration                 | ◐ **Partial**  | `keyboardforge_phase3_linux_integration.zip` |
| 4     | Command-Line Interface (CLI)        | ◐ **Partial**  | `keyboardforge_phase4_cli.zip`                |
| 5     | Graphical User Interface (GUI)        | ✅ Complete    | `keyboardforge_phase5_gui.zip`                  |
| 6     | Packaging & Distribution                | ◐ **Partial**  | `keyboardforge_phase6_packaging.zip`              |
| 7     | Documentation & Quality Assurance         | ✅ Complete    | `keyboardforge_phase7_docs_qa.zip`                  |
| 8     | Windows Keyboard Customization               | ⏸ **Deferred** | not implemented                                       |

Each phase's zip is **cumulative** — it contains everything from all prior
phases plus that phase's new work, so any zip can be unpacked and used
standalone as a snapshot of the project at that point.

Phases 3 and 4 are partial because the Linux installer is still fixed to
`fr_custom`/`custom`, despite the core and CLI supporting other layouts for
editing and export. Phase 6 is partial because native Linux package-build
automation is not wired up.

Phase 8 (Windows) is intentionally **not implemented**. Windows and macOS
remain future work while the Linux module is being completed; no work on
those platform adapters is included in the current scope. Phase 6 is partial:
Python packages can be built, but native Linux package templates are not yet
wired to automated build pipelines.

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
# 1. Validate everything (core engine tests, Linux installer tests, CLI/GUI tests)
./tests/run_all_tests.sh

# 2. See what keyboard layouts your OS already has installed
cd cli && python3 -m keyboardforge_cli system-layouts

# 3. Import one of them (including resolvable `include` chains) for editing
python3 -m keyboardforge_cli import-system fr ../layouts/my_french.json --variant azerty

# 4. Export edited layouts to XKB files. The current installer installs only
#    the bundled fr_custom layout; arbitrary layout installation is not yet supported.
mkdir -p ../xkb-preview
python3 -m keyboardforge_cli export ../layouts/my_french.json ../xkb-preview/
```

See `docs/installation-guide.md`, `docs/user-guide.md`, `docs/cli-manual.md`,
and `docs/gui-manual.md` for details on each component. See
`GIT_WORKFLOW.md` for a complete, phase-by-phase guide to committing and
pushing this project to your own GitHub repository.

## Design principles

- **Linux-first, platform-adaptable:** a common core (`core/`) with
  platform-specific adapters. Linux is the current implementation; Windows
  and macOS are deferred until the Linux module is complete.
- **Single source of truth:** every layout is defined once as JSON in
  `layouts/`. The XKB symbol file and rules XML consumed by the Linux
  installer are *generated artifacts*, not hand-maintained duplicates.
- **Self-contained distribution:** the Linux installer auto-installs its own
  small dependency list (`libxml2`/`xmllint`) rather than assuming it's
  present.
- **Reliability:** every generated layout is validated before it can be
  installed.
