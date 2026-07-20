# GUI Manual

Open `gui/index.html` in any modern browser. No install, no server, no
internet connection required. See `docs/installation-guide.md` section 7
if you haven't opened it yet.

## Table of contents

1. [Toolbar reference](#1-toolbar-reference)
2. [Editing a key](#2-editing-a-key)
3. [How symbols are displayed](#3-how-symbols-are-displayed)
4. [Drag-and-drop](#4-drag-and-drop)
5. [Where your layouts come from](#5-where-your-layouts-come-from)
6. [Saving and installing](#6-saving-and-installing)
7. [Known limitations](#7-known-limitations)

---

## 1. Toolbar reference

| Control | Effect |
|---|---|
| **New Layout** | Starts a blank layout named `new_layout`/`custom` -- rename it by editing the downloaded JSON's `xkb_name`/`variant`/`description` fields, or by creating it with the CLI's `new` command first and loading the result (see Known Limitations) |
| **Load JSON** | Opens a `.json` layout file from disk |
| **Save JSON** | Downloads the current in-memory layout as `<xkb_name>.json` |
| **Undo / Redo** (or Ctrl+Z / Ctrl+Y) | Steps through edit history (up to 50 steps) |
| **Level** dropdown | Which shift level (1-4) the keycaps currently display |
| **Search box** | Highlights keys whose keycode or any raw symbol *name* matches (case-insensitive); non-matching keys dim. Search matches on the technical name (e.g. typing "ampersand" finds the `&` key), not the displayed character, since that's easier to type reliably |
| **Zoom slider** | Scales the keyboard visualization |
| **Toggle Theme** | Switches light/dark |

## 2. Editing a key

1. Click a key on the keyboard.
2. The right-hand panel shows four text inputs (Level 1-4) and a Comment
   field. These inputs hold the raw keysym **name** (e.g. `ampersand`,
   `eacute`, `dead_circumflex`) -- type the name, not the character, here.
   Edit any of them and press Tab/Enter/click away -- changes apply
   immediately (the keycap updates in real time, showing the resulting
   character) and are recorded in the undo history.
3. **Delete key** removes it from the layout entirely.

If you don't know a symbol's technical name, drag it from the palette
instead (section 4) rather than typing it, or check
`docs/user-guide.md` section 4 for the most common names.

## 3. How symbols are displayed

Keycaps show the **actual character** a key produces -- `&` rather than
the technical name `ampersand`, `é` rather than `eacute` -- matching what
you'd see on a real, physical keycap. This applies at whichever shift
level the **Level** dropdown is currently set to.

**Dead keys** (symbols like `dead_circumflex` that modify the *next*
keystroke rather than producing a character themselves) are shown with
their accent glyph (e.g. `^`, `¨`, `` ` ``) and a **dashed border**, so
you can tell at a glance that a key is a dead key rather than a key that
produces that character directly.

**Hovering** any key shows a tooltip with its technical keycode and
(if defined) the raw symbol name at the currently displayed level --
useful when you need the exact name to type elsewhere (e.g. in a script).

The display table covers the large majority of real-world symbols across
Latin, Cyrillic, Greek, Arabic, and common typographic/currency symbols
(see `docs/developer-guide.md` for the exact, continuously-verified
coverage figure). If a symbol has no display mapping, the key falls back
to showing its technical name rather than appearing blank -- so you can
always see and correct what's actually defined there, even for something
exotic.

## 4. Drag-and-drop

The symbol palette below the keyboard lists common keysyms (letters,
digits, punctuation, dead keys, currency symbols) -- shown as their actual
characters, matching the keycap convention above. Drag one onto a key to
set it at the *currently selected Level* (per the Level dropdown). This is
the fastest way to build up a layout without typing keysym names by hand.

## 5. Where your layouts come from

The GUI opens **any** KeyboardForge layout JSON file -- it has no built-in
assumption about which one you're working with. Two starting points:

- **A layout you build from scratch:** click **New Layout**, then add keys
  one at a time.
- **A real layout your operating system already has installed** (its
  actual `us`, `fr`, `de`, etc. layout, fully populated): the GUI itself
  has no filesystem access to detect or import these directly (it's a
  static webpage), so use the CLI first:
  ```bash
  keyboardforge system-layouts fr
  keyboardforge import-system fr ~/my_french.json --variant azerty
  ```
  then **Load JSON** the resulting file here to continue editing visually.

`layouts/fr_custom.json` (loadable the same way as any other file) is
bundled purely as a ready-to-explore example -- it is not treated
specially by the GUI in any way.

## 6. Saving and installing

The GUI only edits the JSON model -- it has no backend, so it cannot write
to `linux/` or run the installer itself. After **Save JSON**:

```bash
cd cli
python3 -m keyboardforge_cli install ~/Downloads/my_custom.json
```

## 7. Known limitations

- No inline editor for the layout's own metadata (`xkb_name`, `variant`,
  `description`, `language`) after creation -- edit the downloaded JSON's
  top-level fields directly in a text editor, or use `keyboardforge new`
  with the CLI first and load the result. Tracked as future work.
- The palette is a curated common-symbols list, not the full XKB keysym
  database -- for anything exotic, type the keysym name directly into a
  Level input (see `docs/user-guide.md` section 4 for the naming
  conventions).
- No built-in way to detect/import your operating system's real layouts
  directly from the browser (this requires filesystem access the GUI
  deliberately doesn't have) -- use `keyboardforge import-system` via the
  CLI first, as described in section 5.
- Physical keyboard geometry is fixed to the standard alphanumeric block
  (`TLDE`/`AE`/`AD`/`AC`/`AB`/`BKSL`/`LSGT`) -- modifier keys themselves
  (Shift/Ctrl/Alt remapping) and compose-key sequence configuration are not
  yet exposed in the GUI. See `docs/architecture.md` and the project
  roadmap's Future Scope for planned expansion.
