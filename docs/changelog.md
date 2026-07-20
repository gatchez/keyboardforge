# Changelog

## [Unreleased] -- KeyboardForge 0.1.0

### Added
- Renamed the project from "FR_CUSTOM Layout Installer Framework" to
  **KeyboardForge**, restructured as a multi-component project:
  `core/`, `linux/`, `cli/`, `gui/`, `packaging/`, `docs/`.
- **Core keyboard engine** (`core/keyboardforge_core`): a dependency-free
  `Layout`/`Key` model, a validator, an XKB generator, and an XKB parser
  (JSON is now the single source of truth for every layout).
- **Real OS-installed layout detection and import**
  (`core/keyboardforge_core/system_layouts.py`, CLI's `system-layouts` and
  `import-system` commands): detects every layout and variant your Linux
  distribution's `xkb-data` package advertises (via evdev.xml), and
  imports any of them into a fully-populated KeyboardForge layout JSON --
  including **recursively resolving `include` chains** (with cycle
  protection), so layouts that define most of their keys via `include`
  (e.g. the real British English and German "basic" variants) import
  completely rather than nearly empty. Validated against genuine
  `xkb-data` files (138 layouts, 6,600+ distinct real-world keysyms), not
  synthetic fixtures.
- **Multi-variant XKB parsing** (`xkb_parser.py` rewrite): real system
  symbols files commonly define dozens of variants in one file with
  comments and tab formatting the previous single-block, comment-naive
  parser couldn't handle; the parser now strips comments correctly and
  extracts each variant block via brace-depth counting rather than a
  single regex.
- **`layouts/fr_custom.json`**: the bundled French custom layout,
  reconstructed as data instead of hand-written XKB text, and explicitly
  documented throughout as example/seed data -- not a special-cased
  subject of the architecture.
- **`tools/generate_layout.py`**: build step turning a layout JSON file
  into the `linux/` installer's expected `fr_custom`/`rules` files.
- **Arch Linux support** (`linux/modules/arch.sh`): pacman dependency
  installation, `localectl`-based X11 keymap configuration, optional
  `mkinitcpio -P`, full install/uninstall parity with Debian and Fedora.
- **CLI** (`cli/keyboardforge_cli`): `new`, `set-key`, `remove-key`,
  `validate`, `export`, `import`, `import-system`, `system-layouts`,
  `list`, `install`, `uninstall`.
- **GUI** (`gui/`): a static, dependency-free visual layout editor --
  keyboard visualization showing **actual characters** (not keysym
  technical names) with dead keys visually distinguished, real-time
  property editing, drag-and-drop symbol palette, undo/redo, search, zoom,
  light/dark theme. The character-display table (`gui/keysyms.js`) covers
  Latin, Cyrillic, Greek, and Arabic scripts plus common typographic
  symbols, prioritized by real-world frequency across every layout
  `xkb-data` ships (continuously verified at >85% real coverage by
  `gui/test_keysyms.js`, not a fixed claim).
- **Packaging**: `.deb`/`.rpm`/`PKGBUILD` templates (rebranded), plus
  `pyproject.toml` for both `keyboardforge-core` and `keyboardforge-cli`
  with a `keyboardforge` console entry point.
- Full documentation set under `docs/`, written for readers with no prior
  assumed knowledge of Linux, Python, or keyboard layout internals.
- `tests/run_all_tests.sh` and `tests/test_end_to_end.sh` tying every
  component's test suite together, plus a real cross-component integration
  test (JSON layout -> generated XKB files -> real install -> real
  uninstall, verified byte-identical system state before/after).
- `.github/workflows/ci.yml`, issue templates, and a pull request template
  for GitHub.

### Fixed (carried over from the 1.2.0 Linux installer prototype, verified again during the KeyboardForge rebuild)
- `backup_file()` in `linux/modules/common.sh` used to write to disk even
  during `--dry-run`. Fixed: dry-run now makes zero filesystem changes,
  confirmed via `md5sum` before/after.
- `apply_debian_system_config` crashed if `/etc/default/keyboard` didn't
  exist (common on minimal/container systems). Fixed: creates it, with a
  sentinel file so `uninstall.sh` fully reverses the "file didn't exist"
  state rather than leaving a stray file behind.
- `linux/uninstall.sh` called system tools (`dpkg-reconfigure`,
  `update-initramfs`, `localectl`, `dracut`) directly instead of through
  `safe_exec`, so a missing tool tripped the global error trap instead of
  producing a clean warning. Fixed: routed through `safe_exec` with
  `command -v` guards, matching `install.sh`'s pattern.
- The original hand-written `fr_custom`/`rules` files had two different
  description strings (one in the symbols file, one in the rules XML) that
  could silently drift apart. Fixed structurally: both are now generated
  from the single `description` field in the layout JSON.
- The first draft of the keysym hex-codepoint decoder in `gui/keysyms.js`
  used an overly rigid regex that failed to match KeyboardForge's own
  `0x10000b2`-style tokens for most codepoint values; fixed to decode any
  hex length after `0x` and subtract the XKB `0x01000000` offset generically.
- A GUI smoke test change exposed that adding a symbol-name tooltip to
  each key (`title = "AE01 (ampersand)"`) broke any code relying on
  `title` being exactly the keycode -- fixed by adding a dedicated
  `data-keycode` attribute for reliable lookup, keeping the richer
  tooltip text for humans.

## 1.2.0 -- FR_CUSTOM Layout Installer Framework (pre-KeyboardForge prototype)
- Debian, Fedora, Arch support; GNOME/KDE/XFCE desktop environment
  configuration; Wayland/X11 detection; timestamped logging; concurrency
  lock; dependency auto-installation; XML validation with rollback on
  corruption; version/upgrade detection.
