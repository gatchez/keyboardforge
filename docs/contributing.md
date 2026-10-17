# Contributing

## Ground rules

- Every component ships its own tests; don't add code without a
  corresponding test (`core/tests/`, `cli/tests/`, `linux/test.sh`,
  `gui/test_logic.js` / `gui/smoke_test.js`, or `tests/test_end_to_end.sh`
  for cross-component behavior).
- Run `./tests/run_all_tests.sh` (or `make test`) before submitting -- it
  should pass with zero failures in the supported environment.
- Follow the coding standards in `docs/architecture.md` (Bash: `safe_exec`
  for every system call, `--dry-run` must never write to disk; Python:
  stdlib-only for `core/`, type hints on public functions; JS: no build
  step, no external CDN dependency for the GUI itself).
- Keep `core/` dependency-free. If a feature needs a third-party package,
  it belongs in `cli/` or `gui/`, not `core/`.

## Adding a feature to the layout model

See "Extending the model" in `docs/developer-guide.md`.

## Adding a new Linux distro

See "Adding a new Linux distro" in `docs/developer-guide.md`.

## Reporting bugs

Include: which component, your OS/distro/DE if relevant, the exact command
you ran, the full output, and (for the Linux installer) the relevant lines
from `linux/logs/install.log`.

## Platform scope

Linux is the active implementation. Windows and macOS work is deferred
until the Linux module is complete. Keep contributions focused on the
current Linux scope unless the project maintainers explicitly broaden it.

## Commit hygiene

- One logical change per commit.
- Update `docs/changelog.md` for user-visible changes.
- If you touch generated files (`linux/fr_custom`, `linux/rules`), make
  sure they were regenerated via `tools/generate_layout.py` from
  `layouts/*.json`, not hand-edited -- `linux/steps.txt` says the same.

The Linux installer accepts generated layout names and variants. Direct
invocation defaults to the bundled `fr_custom`/`custom` pair. Independent
management of multiple generated layouts in the shared system rules file
is still pending; avoid documenting simultaneous installs as supported.
