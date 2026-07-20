# Pip packaging

`core/` and `cli/` are independent, pip-installable Python packages.

## Editable install for local development

```bash
pip install -e core/
pip install -e cli/       # depends on keyboardforge-core
```

After this, `keyboardforge` is on your PATH (via the `[project.scripts]`
entry point defined in `cli/pyproject.toml`):

```bash
keyboardforge --help
keyboardforge list layouts/
keyboardforge validate layouts/fr_custom.json
```

## Building distributable wheels

```bash
python3 -m pip install --upgrade build
python3 -m build core/
python3 -m build cli/
```

This produces `core/dist/keyboardforge_core-*.whl` and
`cli/dist/keyboardforge_cli-*.whl`, installable with
`pip install <wheel file>` on any machine with Python >= 3.8 -- no other
runtime dependencies are required for `keyboardforge-core` (stdlib only).

## Dependency graph

```
keyboardforge-cli  --depends on-->  keyboardforge-core
```

The GUI (`gui/`) has no pip package of its own -- it's a static site with
no server-side component, so it's just distributed as files.
