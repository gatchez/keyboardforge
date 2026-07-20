"""keyboardforge_core.xkb_parser

Parses XKB symbols text and the evdev.xml `<layout>` rules stub back into a
Layout model. Two usage modes:

1. **Round-tripping KeyboardForge's own generated files** (the common
   case for `keyboardforge import <symbols> <rules> <out.json>` on files
   this project produced itself) -- `parse_layout()`.
2. **Importing a real OS-installed system layout** (e.g.
   `/usr/share/X11/xkb/symbols/fr`, which -- unlike our own generated
   files -- typically contains *dozens* of `xkb_symbols "<variant>" { ... }`
   blocks in one file, tab-formatted, with comments, `key.type[group1]=...;`
   attribute lines, and up to 4+ levels per key). See
   `keyboardforge_core.system_layouts` for the higher-level, filesystem-
   aware API built on top of this module -- that's almost always what you
   want for "load one of my OS's built-in layouts", rather than calling
   the functions here directly.

This is a *pragmatic* parser, not a full XKB grammar implementation: it
does not understand nested groups beyond Group1, `modifier_map` blocks, or
conditional/computed symbols. See `docs/developer-guide.md` for the exact
documented boundary of what it does and doesn't handle, and
`core/tests/test_xkb_parser_real_files.py` for it being exercised against
genuine files shipped by the `xkb-data` package (not just our own
generator's output).
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from typing import Dict, List, Optional

from .model import Key, Layout

_SYMBOLS_HEADER_RE = re.compile(r'xkb_symbols\s+"([^"]+)"\s*\{')
_DEFAULT_WORD_RE = re.compile(r'\bdefault\b')
_NAME_RE = re.compile(r'name\[Group1\]\s*=\s*"([^"]*)"')
_INCLUDE_RE = re.compile(r'include\s+"([^"]+)"')
_KEY_RE = re.compile(
    r'key\s*<([A-Za-z0-9_]+)>\s*\{([^{}]*)\}\s*;'
)
_FIRST_BRACKET_GROUP_RE = re.compile(r'\[([^\]]*)\]')


def strip_comments(text: str) -> str:
    """Remove `// line` and `/* block */` comments, respecting double-quoted
    strings (so a `//` or `/*` inside a `name[Group1]="...";` string, however
    unlikely, is left alone)."""
    out = []
    i = 0
    n = len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == '"' and text[i - 1] != "\\":
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            # line comment -- skip to end of line, keep the newline itself
            j = text.find("\n", i)
            i = n if j == -1 else j
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def find_symbols_blocks(text: str) -> Dict[str, dict]:
    """Locate every `xkb_symbols "<variant>" { ... }` block in `text` and
    return {variant_name: {"body": inner_text, "is_default": bool}}.

    Uses brace-depth counting (not a single greedy/non-greedy regex) to find
    each block's true closing brace, since key definitions inside the block
    have their own `{ }` pairs (e.g. `key <AE01> { [ 1, exclam ] };`) that
    would otherwise be mistaken for the block's end.

    A block is considered the file's "default" variant if the standalone
    word `default` appears anywhere between the end of the previous block
    (or the start of the file) and this block's `xkb_symbols` keyword --
    this is where XKB convention puts it (typically as
    `default partial alphanumeric_keys\\nxkb_symbols "basic" {`), but this
    deliberately does not require the word `partial` to also be present, so
    it still works on headers that omit it.
    """
    clean = strip_comments(text)
    blocks: Dict[str, dict] = {}
    search_from = 0

    for header in _SYMBOLS_HEADER_RE.finditer(clean):
        variant_name = header.group(1)
        preceding = clean[search_from:header.start()]
        is_default = bool(_DEFAULT_WORD_RE.search(preceding))

        brace_start = header.end() - 1  # position of the '{' just matched
        depth = 0
        end = None
        j = brace_start
        in_string = False
        while j < len(clean):
            c = clean[j]
            if in_string:
                if c == '"' and clean[j - 1] != "\\":
                    in_string = False
            elif c == '"':
                in_string = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    end = j
                    break
            j += 1
        if end is None:
            continue  # unbalanced braces -- skip this block rather than guess

        body = clean[brace_start + 1:end]
        blocks[variant_name] = {"body": body, "is_default": is_default}
        search_from = end + 1

    return blocks


def _parse_block_body(body: str) -> dict:
    """Parse one xkb_symbols block's inner text into
    {description, base_layout, includes, keys}."""
    name_match = _NAME_RE.search(body)
    description = name_match.group(1) if name_match else ""

    includes = _INCLUDE_RE.findall(body)
    base_layout = includes[0] if includes else None
    extra_includes = includes[1:] if len(includes) > 1 else []

    keys: Dict[str, Key] = {}
    for m in _KEY_RE.finditer(body):
        keycode = m.group(1).upper()
        inner = m.group(2)
        # A key definition may carry attributes (e.g. `type="FOUR_LEVEL",`)
        # before its symbol list, and in rare 6/8-level system layouts more
        # than one bracket group. KeyboardForge's model is single-group
        # (Group1), so we take the *first* `[ ... ]` found -- matching what
        # every KeyboardForge-generated file already looks like.
        bracket_match = _FIRST_BRACKET_GROUP_RE.search(inner)
        if not bracket_match:
            continue
        levels = [lvl.strip() for lvl in bracket_match.group(1).split(",")]
        levels = [lvl for lvl in levels if lvl]
        if not levels:
            continue
        keys[keycode] = Key(keycode=keycode, levels=levels)

    return {
        "description": description,
        "base_layout": base_layout,
        "includes": extra_includes,
        "keys": keys,
    }


def list_variants_in_symbols_text(text: str) -> List[str]:
    """Return every variant name defined in a (possibly multi-variant)
    XKB symbols file's text, in the order they appear."""
    return list(find_symbols_blocks(text).keys())


def parse_symbols(text: str, variant: Optional[str] = None) -> dict:
    """Parse an XKB symbols file's text into a plain dict:
    {variant, description, base_layout, includes, keys: {code: Key}}

    If the file defines multiple variants (as real system files almost
    always do) and `variant` isn't given, picks -- in order of preference --
    the block marked `default`, then a block literally named "basic", then
    simply the first block found. Pass `variant` explicitly to select any
    other one.
    """
    blocks = find_symbols_blocks(text)
    if not blocks:
        return {"variant": variant or "custom", "description": "",
                "base_layout": None, "includes": [], "keys": {}}

    if variant is not None:
        if variant not in blocks:
            raise KeyError(
                f"Variant '{variant}' not found. Available: {', '.join(blocks.keys())}"
            )
        chosen = variant
    else:
        default_block = next((name for name, b in blocks.items() if b["is_default"]), None)
        if default_block:
            chosen = default_block
        elif "basic" in blocks:
            chosen = "basic"
        else:
            chosen = next(iter(blocks.keys()))

    parsed = _parse_block_body(blocks[chosen]["body"])
    parsed["variant"] = chosen
    return parsed


def parse_rules_xml(text: str) -> dict:
    """Parse a `<layout>...</layout>` rules stub (or, for real system files,
    an entire evdev.xml -- see `system_layouts.get_layout_info` for looking
    up a specific layout out of the full file) into a plain dict:
    {xkb_name, description, language, variant, variant_description}
    """
    root = ET.fromstring(text)
    # Accept either a bare <layout> fragment or a full <xkbConfigRegistry>;
    # in the latter case this just grabs the first layout in the file.
    layout_el = root if root.tag == "layout" else root.find(".//layout")
    if layout_el is None:
        raise ValueError("No <layout> element found in rules XML.")

    config_item = layout_el.find("configItem")
    xkb_name = config_item.findtext("name", default="").strip()
    description = config_item.findtext("description", default="").strip()
    language = ""
    lang_list = config_item.find("languageList")
    if lang_list is not None:
        language = (lang_list.findtext("iso639Id", default="") or "").strip()

    variant = ""
    variant_description = ""
    variant_el = layout_el.find("variantList/variant/configItem")
    if variant_el is not None:
        variant = variant_el.findtext("name", default="").strip()
        variant_description = variant_el.findtext("description", default="").strip()

    return {
        "xkb_name": xkb_name,
        "description": description,
        "language": language or "eng",
        "variant": variant,
        "variant_description": variant_description,
    }


def parse_layout(symbols_text: str, rules_text: str, variant: Optional[str] = None) -> Layout:
    """Combine a symbols file and a rules stub into a single Layout.

    `variant` selects which block to use if `symbols_text` defines more
    than one (see `parse_symbols`); it does not need to match anything in
    `rules_text`.
    """
    symbols = parse_symbols(symbols_text, variant=variant)
    rules = parse_rules_xml(rules_text)

    layout = Layout(
        xkb_name=rules["xkb_name"] or "imported_layout",
        variant=rules["variant"] or symbols["variant"],
        description=rules["variant_description"] or symbols["description"] or rules["description"],
        language=rules["language"],
        base_layout=symbols["base_layout"],
        includes=symbols["includes"],
    )
    layout.keys = symbols["keys"]
    return layout
