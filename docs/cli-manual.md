# CLI Manual

This is the complete command reference for `keyboardforge`. For
installation instructions, see `docs/installation-guide.md` section 6. For
conceptual background on layouts, keycodes, and symbols, see
`docs/user-guide.md`.

Install with:
```bash
pip install -e core/
pip install -e cli/
```
which puts `keyboardforge` on your PATH. Or run it directly out of a
checkout without installing anything: `cd cli && python3 -m
keyboardforge_cli <command> ...`.

Every command below is shown as `keyboardforge <command> ...`; substitute
`python3 -m keyboardforge_cli <command> ...` (from inside `cli/`) if you
haven't installed the package.

## Exit codes

Every subcommand returns `0` on success and `1` on any error (validation
failure, missing file, unknown layout/variant, subprocess failure). This
makes every command chainable with `&&` in scripts, e.g.:
```bash
keyboardforge validate my.json && keyboardforge install my.json --yes
```

---

## `keyboardforge new <xkb_name> <variant> <output.json>`

Create a new, empty layout file -- the "start from scratch" path (see
`docs/user-guide.md` section 1 for the alternative, `import-system`).

| Flag | Description |
|---|---|
| `--description TEXT` | Human-readable name shown in DE keyboard pickers |
| `--language CODE` | ISO 639 code, default `eng` |
| `--base LAYOUT` | Base layout to `include` in the generated XKB file, e.g. `us(basic)` |

```bash
keyboardforge new de_custom custom layouts/de_custom.json \
    --description "German (Custom)" --language deu
```

---

## `keyboardforge system-layouts [xkb_name] [--symbols-dir PATH] [--rules-xml PATH]`

Detect what keyboard layouts your operating system itself has installed
(via the `xkb-data` package on Linux) -- the same information a Desktop
Environment's "Add an input source" dialog uses.

**Without an argument**, lists every layout:
```bash
$ keyboardforge system-layouts
us: English (US) (eng) -- 57 variant(s)
fr: French (fra) -- 24 variant(s)
de: German (deu) -- 41 variant(s)
...
138 layout(s) total. Use 'keyboardforge system-layouts <xkb_name>' to list one's variants.
```

**With a layout name**, lists that layout's variants and their
descriptions:
```bash
$ keyboardforge system-layouts fr
fr: French (fra)
  azerty: French (Azerty)
  basic: French
  bepo: French (Bepo, ergonomic, Dvorak way)
  ...
```

| Flag | Description |
|---|---|
| `--symbols-dir PATH` | Where XKB symbol files live (default: `/usr/share/X11/xkb/symbols`) |
| `--rules-xml PATH` | Where the rules/description registry lives (default: `/usr/share/X11/xkb/rules/evdev.xml`) |

If this reports no layout data found, your system doesn't have the
`xkb-data` package installed -- see `docs/troubleshooting.md`.

---

## `keyboardforge import-system <xkb_name> <output.json> [--variant NAME] [--no-resolve-includes]`

Convert a real, OS-installed layout into a KeyboardForge layout JSON,
fully populated and ready to customize.

```bash
keyboardforge import-system fr layouts/my_french.json --variant azerty
keyboardforge import-system us layouts/my_us.json                      # uses the default/basic variant
```

| Flag | Description |
|---|---|
| `--variant NAME` | Which variant to import (default: the layout's default/basic one) |
| `--symbols-dir PATH` | Same as `system-layouts` |
| `--rules-xml PATH` | Same as `system-layouts` |
| `--no-resolve-includes` | See below |

**About `--no-resolve-includes`:** many real system layouts define most of
their keys not directly, but by `include`-ing another layout file (for
example, the UK layout's "basic" variant defines only a handful of keys
itself and pulls in the rest from the US layout). By default,
`import-system` follows these `include` chains recursively so the
resulting JSON is a **complete** layout -- every key the real layout
actually produces, regardless of how many files that's spread across. Pass
`--no-resolve-includes` to instead see *only* what that one variant
defines locally, unresolved (an advanced option -- most people should
leave this off). See `docs/developer-guide.md` for the technical details
of how this resolution works, including cycle protection.

---

## `keyboardforge set-key <layout.json> <KEYCODE> <level1> [level2] [level3] [level4]`

Set (or overwrite) one key's levels. `--comment TEXT` attaches an optional
note, stored in the JSON but not used by the installer.

```bash
keyboardforge set-key layouts/de_custom.json AE01 1 exclam
```

## `keyboardforge remove-key <layout.json> <KEYCODE>`

Remove a key entirely (it reverts to whatever the base layout/system
default defines for that physical key, if any).

## `keyboardforge validate <layout.json>`

Print every validation issue found and exit non-zero if any are errors
(see `docs/user-guide.md` section 6 for the error/warning distinction).
`export`/`install` call this same validator internally and refuse to
proceed if it finds errors.

## `keyboardforge export <layout.json> <output_dir>`

Generate the XKB symbols file (named after `xkb_name`) and the `rules`
XML stub into `output_dir`, without installing anything -- useful for
previewing the generated files, or for feeding a packaging pipeline.

```bash
keyboardforge export layouts/de_custom.json /tmp/preview/
```

## `keyboardforge import <symbols_file> <rules_file> <output.json> [--variant NAME]`

Parse a **KeyboardForge-generated** (or otherwise simple, single- or
multi-variant) XKB symbols file plus its rules XML stub back into a
layout JSON.

| Flag | Description |
|---|---|
| `--variant NAME` | Which block to use if `symbols_file` defines more than one (default: the file's `default`-marked block, else `basic`, else the first one found) |

**This is not the same as `import-system`** (above). `import-system` is
filesystem-aware: it knows where your OS's real layouts live, resolves
`include` chains automatically, and cross-references the OS's own
description/language metadata. `import` just parses whatever two files you
hand it, with no assumptions about where they came from or what they
`include` -- use it for round-tripping KeyboardForge's own output, or
files you've prepared yourself. See `docs/developer-guide.md` for the
precise, documented boundary of what the underlying parser does and
doesn't handle.

## `keyboardforge list [directory]`

List every `*.json` layout file in a directory (default: `layouts/`),
showing its name, variant, description, validity, and key count. Useful
for scripting/batch review.

```bash
$ keyboardforge list layouts/
layouts/fr_custom.json
  fr_custom (custom) -- "French (Custom -- digits on top, ...)" [valid, 48 keys]
```

## `keyboardforge install <layout.json> [--linux-dir PATH] [--dry-run] [--yes]`

Validates the layout, generates its XKB files into `--linux-dir` (default:
the repository's own `linux/`), then runs `install.sh` there. `sudo` is
added automatically if the current process isn't already root. `--dry-run`
and `--yes` are passed straight through to `install.sh` (see
`docs/installation-guide.md` section 5 for exactly what each step does).

```bash
keyboardforge install layouts/de_custom.json --dry-run   # preview, no changes
keyboardforge install layouts/de_custom.json --yes        # for real, no confirmation prompt
```

**Note:** this command *regenerates* `fr_custom`/`rules` (or whatever your
layout's `xkb_name` is) inside `--linux-dir` every time it runs, even
during `--dry-run` -- only the actual system-level installation step is
skipped in `--dry-run` mode. If you're testing against a real checkout of
this repository and don't want to touch its shipped `linux/fr_custom`
file, point `--linux-dir` at a throwaway copy instead.

## `keyboardforge uninstall [--linux-dir PATH]`

Runs `uninstall.sh` in the given (or default) linux directory.
