# Release Notes -- KeyboardForge 0.1.0

**KeyboardForge** is the renamed, restructured successor to the
"FR_CUSTOM Layout Installer Framework" prototype. This release turns that
single-purpose Linux installer into the foundation of a larger, modular
keyboard-layout customization framework, per the project's roadmap Phases
1 (Foundation), 2 (Core Keyboard Engine), 3 (Linux Integration), 4 (CLI),
5 (GUI), 6 (Packaging), and 7 (Documentation & QA).

## Highlights

- **New core engine**: layouts are now defined once as JSON and generated
  into XKB files, instead of being hand-maintained as XKB text in two
  places that could drift apart (and did, in the previous prototype).
- **New: Arch Linux support**, alongside the existing Debian/Ubuntu and
  Fedora support.
- **New: CLI** (`keyboardforge`) for scripting layout creation, editing,
  validation, import/export, and install/uninstall.
- **New: GUI**, a static visual keyboard editor with no install/build step.
- **3 real bugs fixed** in the Linux installer, found through actual
  execution (not just review) during the rebuild -- see `changelog.md` for
  details. All three are now covered by regression tests.
- Every component ships with its own automated tests, tied together by
  `tests/run_all_tests.sh` / `make test`, including a genuine end-to-end
  integration test that installs and uninstalls a generated layout on a
  real system and asserts the filesystem ends up byte-identical to where
  it started.

## Explicitly not in this release

- **Windows support** (Phase 8) -- deferred pending explicit authorization,
  per the project's own scope document. Not started, not stubbed beyond a
  status note in the README.
- Multi-layout-per-install-run management, macOS support, layout sharing /
  community repository, themes-for-layouts (as opposed to GUI theming,
  which is included), plugin architecture, cloud sync, keyboard analytics
  -- all listed under the project's own "Future Scope."
- Automated `.deb`/`.rpm`/pacman package *building* from the templates in
  `packaging/` (the templates/metadata exist; the build pipeline that
  invokes `dpkg-deb`/`rpmbuild`/`makepkg` against them does not yet).
- A GUI panel for editing a layout's own metadata (`xkb_name`, `variant`,
  etc.) after creation -- currently done via the CLI or by editing the
  downloaded JSON directly.

## Upgrading from the 1.2.0 prototype

If you have the old `fr_custom_installer/` checkout: your installed system
layout doesn't need touching. The new `linux/` directory here is
functionally equivalent (same install/uninstall behavior, now with 3 bug
fixes and Arch support) but its `fr_custom`/`rules` files are generated
from `layouts/fr_custom.json` rather than hand-written -- if you'd
customized them by hand, port those changes into the JSON first (or
`keyboardforge import` your customized files into JSON) before
regenerating.
