# User Guide

This guide explains the concepts behind KeyboardForge and walks through
the most common ways people use it. It's written for anyone using the
project -- no assumption is made about whether you're a first-time
Linux user, an experienced system administrator, or a software developer.
If you haven't installed anything yet, start with
`docs/installation-guide.md` first.

## Table of contents

1. [Two ways to start a layout: from scratch, or from your OS](#1-two-ways-to-start-a-layout-from-scratch-or-from-your-os)
2. [The layout model, in plain terms](#2-the-layout-model-in-plain-terms)
3. [Which keycode is which physical key?](#3-which-keycode-is-which-physical-key)
4. [What a "symbol" (keysym) is, and how it's displayed](#4-what-a-symbol-keysym-is-and-how-its-displayed)
5. [Typical workflows](#5-typical-workflows)
6. [Validation](#6-validation)
7. [A note on the bundled example layout](#7-a-note-on-the-bundled-example-layout)

---

## 1. Two ways to start a layout: from scratch, or from your OS

KeyboardForge supports two starting points for building a layout, and
both end up as the exact same kind of JSON file, edited and installed
through the exact same tools:

**Starting from scratch:** build a layout with nothing predefined,
setting only the keys you specifically want to change (`keyboardforge
new`, or the GUI's "New Layout" button). Any key you don't explicitly set
simply isn't part of your layout at all.

**Starting from a real layout already installed by your operating
system:** your Linux distribution ships with dozens to hundreds of
keyboard layouts as part of its `xkb-data` package -- the actual `us`,
`fr`, `de`, `gb`, `es`, and many other real, complete layouts, each often
with several variants (e.g. French has `basic`, `azerty`, `bepo`,
`dvorak`, and over a dozen more). KeyboardForge can detect what's
available on your system and convert any of them into the JSON format,
fully populated with every key that layout defines, ready for you to
tweak a handful of keys rather than build an entire layout by hand:

```bash
keyboardforge system-layouts              # list every layout your OS has
keyboardforge system-layouts fr           # list French's variants specifically
keyboardforge import-system fr my.json --variant azerty
```

This is different from, and unrelated to, `keyboardforge import`, which
parses a *KeyboardForge-generated* (or otherwise simple, single-variant)
XKB symbols file + rules stub pair back into JSON -- see
`docs/cli-manual.md` for exactly when to use which.

---

## 2. The layout model, in plain terms

Whichever way you start, every KeyboardForge layout is a JSON file with
this shape:

```json
{
  "xkb_name": "my_custom",
  "variant": "custom",
  "description": "My Custom Layout",
  "language": "eng",
  "base_layout": null,
  "includes": ["level3(ralt_switch)"],
  "author": "you",
  "version": "1.0.0",
  "keys": [
    { "keycode": "AE01", "levels": ["1", "exclam"] },
    { "keycode": "AE02", "levels": ["2", "at"] }
  ]
}
```

- **`xkb_name`**: the technical identifier XKB and your Desktop Environment
  use internally (letters, digits, and underscores only).
- **`variant`**: distinguishes this layout from others sharing the same
  `xkb_name` "family" -- for a layout you're building yourself, `"custom"`
  is a fine default; for a layout imported from your OS, this will already
  reflect the real variant name (e.g. `"azerty"`, `"dvorak"`).
- **`keys`**: one entry per physical key you want to define. A layout
  built from scratch typically has a handful of entries (just the keys
  you're customizing); a layout imported from your OS will typically have
  40-50+ entries (the OS's complete definition for that layout).
- **`levels`**: what typing that key produces at each shift state --
  index 0 = unshifted, 1 = Shift, 2 = AltGr, 3 = Shift+AltGr. A key can
  define 1 to 4 levels; XKB doesn't require all four.

## 3. Which keycode is which physical key?

KeyboardForge uses the same physical keycodes XKB and every Linux
Desktop Environment use, so a layout you build here behaves identically
to a "native" system layout. The main alphanumeric block:

```
TLDE  AE01 AE02 AE03 AE04 AE05 AE06 AE07 AE08 AE09 AE10 AE11 AE12
      AD01 AD02 AD03 AD04 AD05 AD06 AD07 AD08 AD09 AD10 AD11 AD12
      AC01 AC02 AC03 AC04 AC05 AC06 AC07 AC08 AC09 AC10 AC11  BKSL
LSGT  AB01 AB02 AB03 AB04 AB05 AB06 AB07 AB08 AB09 AB10
```

- `TLDE`: the key to the left of "1" (produces `~`/`` ` `` on a US layout).
- `AE01`-`AE12`: the number row.
- `AD01`-`AD12`: the row starting with Q on a QWERTY layout.
- `AC01`-`AC11`: the row starting with A ("home row").
- `AB01`-`AB10`: the row starting with Z.
- `BKSL`: the ANSI backslash key (top right, above Enter on US keyboards).
- `LSGT`: an extra key present on many non-US ("ISO") keyboards, next to
  the left Shift key.

If you're not sure which physical key a code corresponds to on your own
keyboard, the GUI's visual keyboard (`docs/gui-manual.md`) shows them all
laid out spatially, which is usually the fastest way to check.

## 4. What a "symbol" (keysym) is, and how it's displayed

Internally (in the JSON, and when you type a level into the CLI or the
GUI's property editor), levels are XKB *keysym names* -- fixed technical
identifiers, not the character itself:

- Letters/digits are their own name: `a`, `A`, `1`.
- Named punctuation: `ampersand` (`&`), `at` (`@`), `exclam` (`!`),
  `question` (`?`), `comma`, `period`, `slash`, `asterisk`, `plus`,
  `minus`, `equal`, `underscore`, `bracketleft`/`bracketright` (`[`/`]`),
  `braceleft`/`braceright` (`{`/`}`), `parenleft`/`parenright` (`(`/`)`),
  `less`/`greater`, `bar`, `backslash`, `asciitilde`, `asciicircum`,
  `quotedbl`, `apostrophe`, `grave`.
- Accented/foreign letters: `eacute` (`\u00e9`), `egrave` (`\u00e8`),
  `agrave` (`\u00e0`), `ccedilla` (`\u00e7`), `ugrave` (`\u00f9`), and
  hundreds more covering Latin, Cyrillic, Greek, Arabic, and other scripts
  (whatever your imported/edited layout actually uses).
- **Dead keys** (the *next* keystroke gets accented, rather than the dead
  key itself producing a character): `dead_circumflex`, `dead_diaeresis`,
  `dead_grave`, `dead_acute`, `dead_tilde`, and others.
- Arbitrary Unicode codepoints, for symbols with no short name: either a
  `U` followed by hex digits (e.g. `U2022` for a bullet point `\u2022`), or
  KeyboardForge's own `0x`-prefixed convention (e.g. `0x10000b2` for the
  superscript-two character `\u00b2`) used internally when generating
  XKB files.

**In the CLI and when editing a key's raw value, you work with these
names.** **In the GUI's visual keyboard, keycaps show the actual
character** (e.g. `&`, `é`, `²`) rather than its technical name, exactly
like a real keycap would -- this is specifically to make visual,
at-a-glance customization easier; you don't need to memorize keysym names
to use the GUI. Dead keys are shown with their accent glyph (e.g. `^` for
`dead_circumflex`) and a dashed border, so you can tell them apart from a
key that actually produces that character by itself. If a symbol has no
mapped display character at all (rare -- typically an obscure or
functional keysym), the GUI falls back to showing its technical name
rather than a blank key, so nothing is ever silently hidden. See
`docs/gui-manual.md` for more, and `docs/developer-guide.md` for exactly
what the display table covers.

## 5. Typical workflows

**"I just want to tweak a couple of keys, starting from my own real
keyboard layout":**
```bash
keyboardforge system-layouts                     # find your layout's name
keyboardforge import-system <name> my.json --variant <variant>
```
Then open `my.json` in the GUI to edit visually, or keep using the CLI's
`set-key`.

**"I want to build something entirely new":**
```bash
keyboardforge new my_layout custom my.json --description "..." --language eng
```
or click **New Layout** in the GUI.

**"I want to script/batch-generate several layouts":**
Use the CLI (`docs/cli-manual.md`) -- every operation is one shell
command, composable in scripts, with predictable exit codes.

**"I have an existing hand-written or KeyboardForge-generated XKB file (not
a full OS layout) I want to bring in":**
```bash
keyboardforge import my_symbols_file my_rules_file.xml imported.json
```
See `docs/developer-guide.md` for exactly what subset of XKB syntax this
understands, versus `import-system` (section 1 above) for pulling in a
full, real, installed OS layout.

**"I broke my keyboard and need to revert right now":**
```bash
cd linux && sudo ./uninstall.sh && sudo reboot
```
This works independently of everything else in the project -- it only
needs the `.bak_fr_custom` backups the installer already made, and does
not require Python, Node, or anything from `core/`/`cli/`/`gui/`.

## 6. Validation

Before anything gets installed or exported to XKB files, it's validated.
**Errors** block install/export outright (e.g. zero keys defined, an empty
level, an `xkb_name`/`variant` containing spaces or symbols). **Warnings**
are informative only and never block anything (e.g. an unusual keycode
shape, a language code that isn't a recognized 3-letter form). Run
`keyboardforge validate <file.json>` at any time to check a layout without
generating or installing anything.

## 7. A note on the bundled example layout

`layouts/fr_custom.json` ships with the project as a worked example --
something every tool (CLI, GUI, tests) can load out of the box to
demonstrate the whole pipeline end to end, from a JSON layout definition
through to a real, installed, working keyboard layout. It is not
special-cased anywhere in the code: everything this guide describes
applies identically whether you're working with that example, a layout
you built from scratch, or one imported from your operating system.
