"""keyboardforge_core.model

The internal keyboard representation. A `Layout` is a named, versionable
collection of `Key` definitions plus metadata (XKB identifier, variant,
description, language, includes). This is the object every other
component (parser, generator, validator, CLI, GUI) reads and writes.
"""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Dict, List, Optional
import json


@dataclass
class Key:
    """A single physical key and its per-level symbols.

    ``keycode`` is the XKB physical key identifier, e.g. ``AE01`` (top row,
    first key right of Tab... no -- top number row), ``AD01`` (Q), ``AC01``
    (A), ``AB01`` (Z), ``TLDE`` (tilde/backtick key), ``LSGT`` (the extra
    key some ISO keyboards have next to left Shift), ``BKSL`` (backslash).

    ``levels`` is an ordered list of XKB keysym names, one per shift level:
    index 0 = unshifted (Level1), index 1 = Shift (Level2), index 2 = AltGr
    (Level3), index 3 = Shift+AltGr (Level4). A key may define anywhere from
    1 to 4 levels; XKB fills in unspecified trailing levels automatically.
    """

    keycode: str
    levels: List[str] = field(default_factory=list)
    comment: Optional[str] = None

    def to_dict(self) -> dict:
        d = {"keycode": self.keycode, "levels": list(self.levels)}
        if self.comment:
            d["comment"] = self.comment
        return d

    @staticmethod
    def from_dict(d: dict) -> "Key":
        return Key(
            keycode=d["keycode"],
            levels=list(d.get("levels", [])),
            comment=d.get("comment"),
        )


@dataclass
class Layout:
    """A complete keyboard layout definition."""

    xkb_name: str                       # e.g. "fr_custom" -- the XKB symbols file/identifier
    variant: str                        # e.g. "custom" -- the xkb_symbols "<variant>" block name
    description: str                    # human-readable name shown in DE keyboard pickers
    language: str = "eng"               # ISO 639 code, e.g. "fra"
    base_layout: Optional[str] = None   # e.g. "fr(basic)" to `include` as a starting point
    includes: List[str] = field(default_factory=list)  # extra includes, e.g. "level3(ralt_switch)"
    author: str = ""
    version: str = "1.0.0"
    keys: Dict[str, Key] = field(default_factory=dict)  # keyed by keycode

    # -- construction helpers -------------------------------------------------
    def set_key(self, keycode: str, levels: List[str], comment: Optional[str] = None) -> None:
        keycode = keycode.upper()
        self.keys[keycode] = Key(keycode=keycode, levels=list(levels), comment=comment)

    def remove_key(self, keycode: str) -> None:
        self.keys.pop(keycode.upper(), None)

    def duplicate(self, new_xkb_name: str, new_variant: str) -> "Layout":
        clone = Layout.from_dict(self.to_dict())
        clone.xkb_name = new_xkb_name
        clone.variant = new_variant
        return clone

    # -- serialization ---------------------------------------------------------
    def to_dict(self) -> dict:
        return {
            "xkb_name": self.xkb_name,
            "variant": self.variant,
            "description": self.description,
            "language": self.language,
            "base_layout": self.base_layout,
            "includes": list(self.includes),
            "author": self.author,
            "version": self.version,
            "keys": [k.to_dict() for k in self.keys.values()],
        }

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent, ensure_ascii=False)

    @staticmethod
    def from_dict(d: dict) -> "Layout":
        layout = Layout(
            xkb_name=d["xkb_name"],
            variant=d["variant"],
            description=d.get("description", ""),
            language=d.get("language", "eng"),
            base_layout=d.get("base_layout"),
            includes=list(d.get("includes", [])),
            author=d.get("author", ""),
            version=d.get("version", "1.0.0"),
        )
        for kd in d.get("keys", []):
            key = Key.from_dict(kd)
            layout.keys[key.keycode] = key
        return layout

    @staticmethod
    def from_json(text: str) -> "Layout":
        return Layout.from_dict(json.loads(text))

    @staticmethod
    def load(path: str) -> "Layout":
        with open(path, "r", encoding="utf-8") as f:
            return Layout.from_json(f.read())

    def save(self, path: str) -> None:
        with open(path, "w", encoding="utf-8") as f:
            f.write(self.to_json())
            f.write("\n")
