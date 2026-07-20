# Developer Guide

See `docs/architecture.md` first for the overall component map and data
flow. This document covers implementation details for contributors.

## Repository layout

See the root `README.md` for the directory tree. The short version: `core/`
has zero runtime dependencies and zero I/O side effects outside functions
that explicitly take a path; `cli/` and `gui/` are both thin clients over
it; `linux/` is a standalone, independently-testable Bash component that
happens to consume `core/`'s output but doesn't import it directly.

## Core engine internals

### `model.py`

`Key` and `Layout` are plain dataclasses. `Layout.keys` is a
`Dict[str, Key]` keyed by uppercased keycode -- this is what makes "does
this layout already define AE01" an O(1) check instead of a scan.

### `validator.py`

Returns a `list[ValidationIssue]` rather than raising, so callers (CLI,
GUI eventually, generator) can decide what to do with warnings vs. errors.
`has_errors()` is the single predicate every caller should gate on before
generating/installing.

### `xkb_generator.py`

Pure string templating, no filesystem access except in `generate()`,
which is a thin wrapper that calls the two string-producing functions and
writes them to disk. Keeping the string-producing functions
filesystem-free is what makes them trivially unit-testable (see
`core/tests/test_core.py`).

### `xkb_parser.py`

Handles two distinct jobs, and it's important to understand the boundary
between them:

1. **Comment stripping** (`strip_comments`): removes `// line` and
   `/* block */` comments while respecting quoted strings, as a
   preprocessing pass before anything else runs.
2. **Multi-variant block extraction** (`find_symbols_blocks`): a single
   real-world XKB symbols file (e.g. `/usr/share/X11/xkb/symbols/fr`)
   commonly defines *dozens* of `xkb_symbols "<variant>" { ... }` blocks
   in one file. This function locates every one of them using **brace-depth
   counting**, not a single greedy/non-greedy regex -- because key
   definitions inside a block have their own `{ }` pairs (e.g.
   `key <AE01> { [ 1, exclam ] };`) that would otherwise be mistaken for
   the block's own closing brace. It also detects which block (if any) is
   marked `default` by looking for that standalone word between the
   previous block and this one, independent of whether the word
   `partial` is also present (real files vary on this).
3. **Per-block parsing** (`_parse_block_body`, exposed via `parse_symbols`):
   extracts `name[Group1]`, `include` statements, and `key <CODE> { ... };`
   definitions from one block's already-isolated body text. Key parsing is
   deliberately permissive: it captures everything between a key's `{ }`
   (again via a non-nested-brace assumption, which holds for real key
   definitions) and then takes the *first* `[ ... ]` bracket group found
   inside that as the Group1 symbol list -- ignoring any `type="..."`
   attribute that might precede it, and ignoring any additional
   Group2+/multi-group bracket lists that might follow it (KeyboardForge's
   model is intentionally single-group).

**What this parser deliberately does not do:** resolve nested XKB grammar
beyond the above (no `modifier_map` blocks, no computed/conditional
symbols, no multi-group Group2+ definitions), and -- critically -- **it
does not follow `include` statements itself**. `parse_symbols()`/
`parse_layout()` record `base_layout`/`includes` as plain metadata on the
returned `Layout`; they do not open other files. That's a deliberate
separation: this module has zero filesystem access, which is what makes
it trivially unit-testable in isolation (see
`core/tests/test_xkb_parser_real_files.py`, which exercises it against
genuine files from the `xkb-data` package, not just KeyboardForge's own
generated output).

### `system_layouts.py`

This is where filesystem awareness and `include` resolution actually
live, because they're a different concern from parsing one file's text.

- **`list_available_layouts()`**: parses the *entire* evdev.xml rules
  registry (not just one `<layout>` fragment) via `ElementTree`, returning
  every layout and variant name/description/language the OS advertises --
  the same data a Desktop Environment's input-source picker uses.
- **`list_variants()`**: the ground-truth list of variant blocks
  physically present in one symbols file (via `xkb_parser.
  list_variants_in_symbols_text`), which can be a superset of what
  evdev.xml lists (evdev.xml's variant list is curated/user-facing; some
  blocks exist in the file purely to be `include`-d by other blocks and
  aren't meant to be selected directly).
- **`import_system_layout(xkb_name, variant, resolve_includes=True)`**:
  the main entry point. **Why `resolve_includes` exists and defaults to
  `True`:** many real "basic" variants (British English and German are
  the clearest real-world examples) define only a handful of keys
  locally and pull in the rest via `include "other_layout(variant)"`.
  Importing just the named block, unresolved, would produce a
  near-empty layout for these -- not what "import my system's real
  layout" should mean. `_resolve_include_keys()` recursively follows
  `include` tokens (format: `file` or `file(variant)`), loading and
  parsing each referenced file via `xkb_parser.parse_symbols()`, merging
  results with **the including block's own local keys always taking
  priority** (matching XKB's own override semantics), with:
  - **Cycle protection**: a `seen` set of already-visited `file(variant)`
    tokens per resolution chain, so a (hypothetical, not expected in real
    `xkb-data`) circular `include` cannot cause infinite recursion --
    covered by `core/tests/test_system_layouts.py::
    test_include_cycle_does_not_infinite_loop` using a synthetic
    pathological fixture.
  - **A hard depth limit** (`max_depth=12`) as a second, independent
    backstop.
  - **Best-effort resolution**: a missing file, an unknown variant name,
    or a malformed include token resolves to `{}` (contributes nothing)
    rather than raising -- a partially-resolved import is far more useful
    than one that hard-fails because of one obscure/behavioral include
    target (e.g. `level3(ralt_switch)`, which exists for its *modifier*
    behavior and may define few or no printable keys itself).

  When `resolve_includes=True`, the returned `Layout`'s own
  `base_layout`/`includes` fields are cleared (`None`/`[]`) -- the keys
  are already fully flattened in, so there's nothing left to `include`.
  With `resolve_includes=False`, they're preserved as parsed, unresolved.

## Extending the model

Adding a new field to `Layout` or `Key`:
1. Add the field to the dataclass in `model.py` with a sensible default (so
   existing JSON files without it still load).
2. Update `to_dict()`/`from_dict()` if it needs custom (de)serialization.
3. Update `xkb_generator.py` if it should affect generated output.
4. Update `xkb_parser.py` if it should be recoverable from parsing.
5. Add a test in `core/tests/test_core.py` covering the round trip.

## The Linux installer's coding standards

See `docs/architecture.md`'s "Coding standards" section. The short version:
every system-mutating call goes through `safe_exec()` (never a bare
command), every write is preceded by `check_writable()`, every destructive
op is preceded by `backup_file()`, and `--dry-run` must produce *zero*
filesystem writes -- this was a real bug caught during testing (see
`docs/changelog.md`) and is now covered by an integration test.

## Adding a new Linux distro

1. Add `linux/modules/<distro>.sh` with `install_dependencies()` and
   `apply_<distro>_system_config()`, following `modules/arch.sh` as the
   template (it's the shortest, cleanest example).
2. Add an `elif [[ -f /etc/<distro>-marker ]]` branch to both
   `linux/install.sh` and `linux/uninstall.sh`.
3. Add the new module file to the `for f in ...` file-existence check list
   in `linux/test.sh`.
4. Add a packaging template under `packaging/` if relevant.

## The GUI's keysym-to-character table (`gui/keysyms.js`)

Deliberately kept as its own module, separate from `gui/logic.js`, because
it's a large, mostly-static data table plus a small resolution function,
with a different testing concern (real-world coverage measurement) than
`logic.js`'s behavioral unit tests.

**How the table was built:** rather than transcribing an arbitrary subset
of the ~4,000-entry X11 `keysymdef.h`, every layout file shipped by the
`xkb-data` package was scanned to find which keysym names actually appear
in practice, and the table was prioritized by real frequency. The
resulting coverage (Latin script, plus full Cyrillic, Greek, and Arabic
alphabets, plus common typographic/currency symbols) covers the large
majority of real-world usage -- `gui/test_keysyms.js` re-measures this
against whatever `xkb-data` is actually installed on the machine running
the test (not a stale, hand-picked sample) and asserts a concrete
coverage floor, currently >85%.

**What's intentionally not covered, and why that's fine:** a meaningful
chunk of the remaining gap is *functional* keysyms with no printable
glyph by design -- modifier switches (`ISO_Level3_Shift`, `Mode_switch`),
media keys (`XF86AudioMute`), keypad functions (`KP_Enter`), and modifier
names themselves (`Control_L`, `Alt_R`, `Super_L`). Falling back to
showing their technical name for those is correct behavior, not a gap to
close. Beyond that, some very low-frequency scripts (Thai, Hebrew, Kana,
Georgian, Armenian, Sinhala, Devanagari, Braille) aren't yet in the table
-- contributions adding them following the same pattern (a flat name ->
character object, informed by real frequency data) are welcome; see
"Adding to the keysym table" below.

**Adding to the keysym table:**
1. Add entries to the `TABLE` object in `gui/keysyms.js`, grouped under a
   clearly commented section (follow the existing Cyrillic/Arabic/Greek
   sections as the pattern).
2. Re-run `node test_keysyms.js` (or `npm test` from `gui/`) -- the
   coverage percentage it prints will reflect your addition immediately.
3. If you're adding a whole new script, consider adding a small number of
   targeted `charFor()` assertions for it too (see the existing
   "resolves known named symbols" tests), not just relying on the
   aggregate coverage number.

**Why raw symbol lookup (`logic.js`) and display rendering
(`keysyms.js`) are separate modules:** `rawSymbolAtLevel()` in `logic.js`
answers "what keysym name is defined at this level" -- pure data, no
knowledge of Unicode or display concerns, trivially unit-testable.
`charFor()` in `keysyms.js` answers "how should a human see this keysym
name" -- a rendering concern that legitimately needs a large data table.
Keeping them separate means the data-lookup logic (used by, for example,
copy-to-CLI or future export features) never accidentally depends on
having the (much larger) character table loaded, and the character table
can be tested/extended independently of the DOM-facing code that consumes
it.

## Running the full test matrix locally

```bash
./tests/run_all_tests.sh     # everything
make test-core                 # just the core engine
make test-linux                  # just the linux installer
make test-cli                      # just the CLI
make test-gui                        # just the GUI (logic + keysyms + smoke)
```

## A note on the GUI's overall test strategy

`gui/logic.js` and `gui/keysyms.js` are both intentionally DOM-free
(UMD-wrapped so they also `require()` under Node) so their behavior can be
unit tested directly with Node's built-in test runner (`gui/test_logic.js`,
`gui/test_keysyms.js`) -- no browser needed. `gui/smoke_test.js` then
loads the *actual* `index.html`/`app.js`/`logic.js`/`keysyms.js` into a
`jsdom` environment and drives real click/change/drop events through the
real DOM, catching wiring bugs (stale element references, mismatched IDs,
event listeners never attached, a tooltip format change silently breaking
a test's element lookup -- all three of these were real bugs caught this
way during development, not hypothetical examples) that pure logic tests
structurally cannot see. Keep new GUI features testable by keeping their
non-trivial logic in `logic.js`/`keysyms.js`, not inline in `app.js`, and
prefer a dedicated `data-*` attribute over the human-facing `title`
tooltip for anything a test needs to look up by exact value.
