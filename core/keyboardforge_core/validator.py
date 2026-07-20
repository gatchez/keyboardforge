"""keyboardforge_core.validator

Validates a Layout before it is ever generated to XKB files or installed on
a real system. Two severities: "error" (blocks install/export) and
"warning" (allowed, but flagged).
"""

from __future__ import annotations

from dataclasses import dataclass
import re

from .model import Layout

_IDENTIFIER_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
# Valid XKB physical keycodes are 4 characters, letters/digits only.
_KEYCODE_RE = re.compile(r"^[A-Z][A-Z0-9]{3}$")
# A conservative allowlist pattern for keysym names: letters, digits,
# underscore. Doesn't validate against the full XKB keysym database, but
# catches typos, stray punctuation, and empty symbols.
_KEYSYM_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*|[0-9])$")


@dataclass
class ValidationIssue:
    severity: str  # "error" | "warning"
    message: str

    def __str__(self) -> str:
        tag = "ERROR" if self.severity == "error" else "WARNING"
        return f"[{tag}] {self.message}"


def validate(layout: Layout) -> list:
    """Return a list of ValidationIssue. Layout is safe to generate/install
    only if none of the returned issues have severity == 'error'."""
    issues: list = []

    if not _IDENTIFIER_RE.match(layout.xkb_name or ""):
        issues.append(ValidationIssue(
            "error",
            f"xkb_name '{layout.xkb_name}' must start with a letter and contain only "
            "letters, digits, and underscores.",
        ))

    if not _IDENTIFIER_RE.match(layout.variant or ""):
        issues.append(ValidationIssue(
            "error",
            f"variant '{layout.variant}' must start with a letter and contain only "
            "letters, digits, and underscores.",
        ))

    if not layout.description.strip():
        issues.append(ValidationIssue("error", "description must not be empty."))

    if len(layout.language) != 3 or not layout.language.isalpha():
        issues.append(ValidationIssue(
            "warning",
            f"language '{layout.language}' does not look like an ISO 639-2/B code "
            "(expected 3 letters, e.g. 'fra', 'eng').",
        ))

    if not layout.keys:
        issues.append(ValidationIssue("error", "layout defines zero keys."))

    for keycode, key in layout.keys.items():
        if keycode != key.keycode:
            issues.append(ValidationIssue(
                "error",
                f"key dict entry '{keycode}' does not match its own keycode field "
                f"'{key.keycode}'.",
            ))

        if not _KEYCODE_RE.match(keycode):
            issues.append(ValidationIssue(
                "warning",
                f"keycode '{keycode}' doesn't match the usual 4-character XKB "
                "keycode pattern (e.g. AE01, AD01, AC01, AB01, TLDE, LSGT, BKSL). "
                "It will still be emitted, but double check it against your "
                "keyboard's evdev geometry.",
            ))

        if not key.levels:
            issues.append(ValidationIssue(
                "error", f"key '{keycode}' defines zero levels (needs at least 1)."
            ))
        if len(key.levels) > 4:
            issues.append(ValidationIssue(
                "warning",
                f"key '{keycode}' defines {len(key.levels)} levels; only the first "
                "4 (Level1..Level4) are meaningful without an explicit multi-key "
                "level mapping.",
            ))
        for i, sym in enumerate(key.levels):
            if not sym or not sym.strip():
                issues.append(ValidationIssue(
                    "error", f"key '{keycode}' level {i + 1} is empty."
                ))
            elif sym.startswith("0x"):
                # Numeric Unicode keysyms (e.g. 0x10000b2) are valid XKB syntax
                # and intentionally exempted from the identifier pattern check.
                continue
            elif not _KEYSYM_RE.match(sym):
                issues.append(ValidationIssue(
                    "warning",
                    f"key '{keycode}' level {i + 1} symbol '{sym}' doesn't look "
                    "like a standard XKB keysym name (letters/digits/underscore, "
                    "or a 0x-prefixed Unicode codepoint).",
                ))

    if layout.base_layout is not None and not layout.base_layout.strip():
        issues.append(ValidationIssue(
            "warning", "base_layout is set but empty; remove it or give it a value."
        ))

    return issues


def has_errors(issues: list) -> bool:
    return any(i.severity == "error" for i in issues)
