# KeyboardForge GUI

A static, dependency-free visual keyboard layout editor. No build step, no
server, no external CDN -- just open `index.html` in a browser.

## Usage

1. Open `index.html` directly in a browser (double-click it, or `file://` it).
2. Click **New Layout**, or **Load JSON** to open an existing layout from
   `../layouts/`.
3. Click a key to select it, then edit its Level 1-4 symbols and comment in
   the right-hand panel. Changes apply in real time.
4. Use the **Level** dropdown to preview what the keyboard looks like under
   Shift / AltGr / Shift+AltGr, drag symbols from the palette onto a key,
   search for a symbol/keycode, zoom, and toggle light/dark theme.
5. Click **Save JSON** to download the edited layout.

The GUI only edits the JSON layout model -- it does not generate XKB files
or install anything itself (there's no backend). After saving, use the CLI
to go the rest of the way:

```bash
cd ../cli
python3 -m keyboardforge_cli export ../layouts/my_layout.json ../linux/
python3 -m keyboardforge_cli install ../layouts/my_layout.json
```

## Architecture

- `logic.js` -- pure, DOM-free helper functions (level padding, search
  matching, JSON <-> map conversion). Loaded as a plain UMD-style script in
  the browser, and `require()`-able directly under Node for testing.
- `keysyms.js` -- maps XKB keysym *names* (e.g. `"ampersand"`, `"eacute"`,
  `"dead_circumflex"`) to the actual character they produce, so keycaps
  show "&"/"é"/"^" instead of the technical name. Covers the vast majority
  of real-world usage across every layout shipped by the `xkb-data`
  package (Latin, Cyrillic, Greek, Arabic, common typographic symbols, and
  a general fallback rule for arbitrary Unicode-codepoint keysyms) with a
  graceful fallback to the technical name for anything genuinely
  unmapped -- see `test_keysyms.js` for the exact, continuously-verified
  coverage number. Also UMD-style / Node-testable, independent of
  `logic.js`.
- `app.js` -- DOM wiring only: rendering the keyboard grid, the property
  editor, and toolbar event handlers. Delegates all data logic to
  `logic.js` and all symbol-rendering decisions to `keysyms.js`.
- `style.css` -- light/dark theme via CSS custom properties.

## Where layouts come from

The GUI opens *any* KeyboardForge layout JSON file -- there is nothing
`fr_custom`-specific about it. `layouts/fr_custom.json` is bundled purely
as a working example/seed to load and explore; to start from one of your
operating system's own real, built-in layouts instead (its actual `us`,
`fr`, `de`, ... layout, not this example), use the CLI's `import-system`
command first (see `docs/cli-manual.md`), then open the resulting JSON
file here.

## Testing

```bash
npm install       # installs jsdom, a dev-only test dependency
npm test          # runs all three suites below
```

- `test_logic.js` -- unit tests for the pure logic layer (Node's built-in
  test runner, no DOM needed).
- `test_keysyms.js` -- unit tests for the keysym-to-character table,
  including a real-world coverage check that scans every layout file
  actually installed on the machine running the test (not a stale,
  hand-picked sample) and asserts a concrete coverage percentage.
- `smoke_test.js` -- loads the *real* `index.html`/`app.js`/`logic.js`/
  `keysyms.js` into a jsdom environment and drives the actual UI (click a
  key, edit levels, switch the displayed shift level, search, delete,
  undo, toggle theme) to catch DOM-wiring bugs that pure unit tests can't
  see.

`node_modules/` (jsdom) is a test-only dependency and is not required to
use the GUI itself -- it's excluded from distribution zips.
