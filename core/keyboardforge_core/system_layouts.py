"""keyboardforge_core.system_layouts

Detects and imports keyboard layouts that ship with the operating system
itself (via the `xkb-data` package on Linux) -- as opposed to
`layouts/fr_custom.json`, which is just one example/seed layout bundled
with KeyboardForge to demonstrate the model. This module is what backs
"Detect installed keyboard layouts" / "Import system layouts" from the
project's functional requirements: it lets you start from e.g. your
system's real `us`, `fr`, `de`, `gb`... layout and customize it, instead of
only ever starting from the bundled example.

Two real-world facts this module deals with that `xkb_parser.py` alone
does not:

1. **One system symbols file defines many variants.** `/usr/share/X11/xkb/
   symbols/fr` alone defines 24 (`basic`, `azerty`, `bepo`, `dvorak`, ...).
   `list_variants()` and `list_available_layouts()` surface this.
2. **Variants heavily reuse each other via `include`.** Many "basic"
   variants define only a handful of keys locally and pull in the rest via
   `include "some_other_layout(variant)"` chains. Naively parsing just the
   one named block leaves most keys undefined for layouts built this way.
   `import_system_layout()` resolves these includes recursively (with
   cycle protection) so the imported layout is actually complete, unless
   you explicitly ask for the raw, unresolved block via
   `resolve_includes=False`.
"""

from __future__ import annotations

import os
import re
import xml.etree.ElementTree as ET
from typing import Dict, List, Optional

from .model import Layout
from .xkb_parser import parse_symbols, list_variants_in_symbols_text

DEFAULT_XKB_SYMBOLS_DIR = "/usr/share/X11/xkb/symbols"
DEFAULT_XKB_RULES_XML = "/usr/share/X11/xkb/rules/evdev.xml"

_INCLUDE_TOKEN_RE = re.compile(r'^([A-Za-z0-9_+\-]+)(?:\(([^)]+)\))?$')

# Files in the symbols directory that are behavioral/modifier fragments
# (AltGr switching, level5 shifting, compose key setup, etc.) rather than
# selectable per-country/per-vendor layouts. Excluded from
# `list_available_layouts()` so it reflects what a Desktop Environment's
# "Add an input source" picker would actually show you, matching evdev.xml's
# own `<layoutList>` -- but NOT excluded from include resolution, since
# layouts legitimately `include` these for their side effects (e.g. every
# layout that supports AltGr includes `level3(ralt_switch)`).
_NON_LAYOUT_AUX_FILES = {
    "level3", "level5", "altwin", "capslock", "ctrl", "compose", "eurosign",
    "keypad", "kpdl", "nbsp", "shift", "srvr_ctrl", "olpc", "empty",
    "inet", "pc", "typo", "custom",
}


class SystemLayoutError(Exception):
    pass


def is_available(symbols_dir: str = DEFAULT_XKB_SYMBOLS_DIR) -> bool:
    """Whether this system actually has XKB layout data installed at all
    (it's provided by the `xkb-data` package, which the KeyboardForge Linux
    installer depends on -- but this module may run on a machine that
    doesn't have it, e.g. inside a minimal container)."""
    return os.path.isdir(symbols_dir)


def list_available_layouts(rules_xml: str = DEFAULT_XKB_RULES_XML) -> List[dict]:
    """Return every layout evdev.xml advertises, in the same form a Desktop
    Environment's keyboard settings panel would show you:
    [{"xkb_name": "fr", "description": "French", "language": "fra",
      "variants": [{"name": "basic", "description": "French"}, ...]}, ...]

    `variants` always includes an implicit "basic"-equivalent default even
    when evdev.xml doesn't list one explicitly by that name -- use
    `list_variants()` against the actual symbols file if you need the
    ground-truth list of every block physically present in the file
    (evdev.xml's variantList is curated/user-facing and is not always a
    100% mirror of what's technically in the symbols file).
    """
    if not os.path.isfile(rules_xml):
        raise SystemLayoutError(
            f"{rules_xml} not found. Is the 'xkb-data' package installed on this system?"
        )
    tree = ET.parse(rules_xml)
    root = tree.getroot()
    results = []
    for layout_el in root.findall(".//layoutList/layout"):
        config_item = layout_el.find("configItem")
        if config_item is None:
            continue
        xkb_name = (config_item.findtext("name") or "").strip()
        description = (config_item.findtext("description") or "").strip()
        language = ""
        lang_list = config_item.find("languageList")
        if lang_list is not None:
            language = (lang_list.findtext("iso639Id") or "").strip()

        variants = []
        for variant_el in layout_el.findall("variantList/variant/configItem"):
            variants.append({
                "name": (variant_el.findtext("name") or "").strip(),
                "description": (variant_el.findtext("description") or "").strip(),
            })

        results.append({
            "xkb_name": xkb_name,
            "description": description,
            "language": language or "und",
            "variants": variants,
        })
    return results


def get_layout_info(xkb_name: str, rules_xml: str = DEFAULT_XKB_RULES_XML) -> dict:
    """Look up one specific layout's evdev.xml entry by xkb_name."""
    for entry in list_available_layouts(rules_xml):
        if entry["xkb_name"] == xkb_name:
            return entry
    raise SystemLayoutError(f"No layout named '{xkb_name}' found in {rules_xml}.")


def list_variants(xkb_name: str, symbols_dir: str = DEFAULT_XKB_SYMBOLS_DIR) -> List[str]:
    """Return every variant block name physically present in
    `<symbols_dir>/<xkb_name>` (the ground truth -- see docstring note on
    `list_available_layouts` about why this can differ from evdev.xml)."""
    path = os.path.join(symbols_dir, xkb_name)
    if not os.path.isfile(path):
        raise SystemLayoutError(f"No symbols file for layout '{xkb_name}' at {path}.")
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return list_variants_in_symbols_text(f.read())


def _resolve_include_keys(
    include_token: str,
    symbols_dir: str,
    seen: frozenset,
    depth: int = 0,
    max_depth: int = 12,
) -> Dict[str, object]:
    """Recursively resolve one `include "file(variant)"` token into the
    keys it (transitively) defines. Returns {} for anything that can't be
    resolved (missing file, unknown variant, cycle, depth limit) rather
    than raising -- a best-effort include is far more useful than an import
    that hard-fails because of one obscure/behavioral include target."""
    if depth > max_depth or include_token in seen:
        return {}
    match = _INCLUDE_TOKEN_RE.match(include_token)
    if not match:
        return {}
    file_name, variant_name = match.group(1), match.group(2)
    path = os.path.join(symbols_dir, file_name)
    if not os.path.isfile(path):
        return {}

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    try:
        parsed = parse_symbols(text, variant=variant_name)
    except KeyError:
        return {}

    next_seen = seen | {include_token}
    merged: Dict[str, object] = {}
    if parsed["base_layout"]:
        merged.update(_resolve_include_keys(parsed["base_layout"], symbols_dir, next_seen, depth + 1, max_depth))
    for inc in parsed["includes"]:
        merged.update(_resolve_include_keys(inc, symbols_dir, next_seen, depth + 1, max_depth))
    merged.update(parsed["keys"])  # this include's own local keys win over what it inherited
    return merged


def import_system_layout(
    xkb_name: str,
    variant: Optional[str] = None,
    symbols_dir: str = DEFAULT_XKB_SYMBOLS_DIR,
    rules_xml: str = DEFAULT_XKB_RULES_XML,
    resolve_includes: bool = True,
) -> Layout:
    """Import a real OS-installed layout (e.g. `xkb_name="fr"`,
    `variant="azerty"`) into a KeyboardForge `Layout`.

    With `resolve_includes=True` (the default), keys the requested variant
    inherits via `include` -- directly or transitively -- are pulled in too
    (with the variant's own locally-defined keys always taking priority),
    so e.g. importing a "basic" variant that's 90% `include`-based still
    produces a fully-populated layout instead of a nearly-empty one. Set it
    to `False` to see exactly (and only) what that one block defines,
    unresolved.

    Description and language are taken from evdev.xml when available
    (matching what a Desktop Environment would display), falling back to
    what's in the symbols file itself if evdev.xml doesn't have an entry
    for this exact layout/variant pair (this happens for some obscure
    variants that exist in the symbols file but aren't user-facing/listed).
    """
    symbols_path = os.path.join(symbols_dir, xkb_name)
    if not os.path.isfile(symbols_path):
        raise SystemLayoutError(f"No symbols file for layout '{xkb_name}' at {symbols_path}.")

    with open(symbols_path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()

    parsed = parse_symbols(text, variant=variant)
    chosen_variant = parsed["variant"]

    keys = dict(parsed["keys"])
    if resolve_includes:
        inherited: Dict[str, object] = {}
        seed_seen = frozenset({f"{xkb_name}({chosen_variant})"})
        if parsed["base_layout"]:
            inherited.update(_resolve_include_keys(parsed["base_layout"], symbols_dir, seed_seen))
        for inc in parsed["includes"]:
            inherited.update(_resolve_include_keys(inc, symbols_dir, seed_seen))
        inherited.update(keys)  # this variant's own local keys always win
        keys = inherited

    description = parsed["description"]
    language = "und"
    try:
        info = get_layout_info(xkb_name, rules_xml)
        language = info["language"] or language
        if chosen_variant == "basic" or not parsed["description"]:
            description = info["description"] or description
        else:
            variant_match = next((v for v in info["variants"] if v["name"] == chosen_variant), None)
            if variant_match:
                description = variant_match["description"] or description
    except SystemLayoutError:
        pass  # evdev.xml unavailable or doesn't know this layout -- use symbols-file data only

    layout = Layout(
        xkb_name=xkb_name,
        variant=chosen_variant,
        description=description or f"{xkb_name} ({chosen_variant})",
        language=language,
        base_layout=parsed["base_layout"] if not resolve_includes else None,
        includes=parsed["includes"] if not resolve_includes else [],
        author="",
        version="1.0.0",
    )
    layout.keys = keys
    return layout
