"""KeyboardForge Core Engine.

A dependency-free (stdlib-only) internal representation of a keyboard
layout, plus a parser (XKB -> model) and generator (model -> XKB) pair, and
a validator. This is the single source of truth that both the CLI and GUI
build on top of.
"""

from .model import Key, Layout
from .validator import ValidationIssue, validate
from . import system_layouts

__all__ = ["Key", "Layout", "ValidationIssue", "validate", "system_layouts"]

__version__ = "0.2.0"
