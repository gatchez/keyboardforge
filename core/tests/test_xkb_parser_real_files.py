"""Tests for keyboardforge_core.xkb_parser against REAL, OS-installed XKB
files (not just KeyboardForge's own generated output). Gated on the
system actually having xkb-data installed, so this suite stays green (via
a skip, not a failure) on a machine that doesn't have it -- but on any
Linux system with X11/xkb-data present (which is most of them), this
exercises the parser against genuine, unmodified real-world data.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest

from keyboardforge_core.xkb_parser import (
    strip_comments,
    find_symbols_blocks,
    list_variants_in_symbols_text,
    parse_symbols,
)

XKB_SYMBOLS_DIR = "/usr/share/X11/xkb/symbols"

pytestmark = pytest.mark.skipif(
    not os.path.isdir(XKB_SYMBOLS_DIR),
    reason="xkb-data not installed on this system (no /usr/share/X11/xkb/symbols)",
)


def read_symbols(name: str) -> str:
    with open(os.path.join(XKB_SYMBOLS_DIR, name), "r", encoding="utf-8", errors="replace") as f:
        return f.read()


# --- comment stripping ------------------------------------------------------

def test_strip_comments_removes_line_and_block_comments():
    text = (
        '// a leading comment\n'
        'key <AE01> { [ 1, exclam ] }; // trailing comment\n'
        '/* a block\n   comment */\n'
        'key <AE02> { [ 2, at ] };\n'
    )
    cleaned = strip_comments(text)
    assert "//" not in cleaned
    assert "/*" not in cleaned
    assert "key <AE01>" in cleaned
    assert "key <AE02>" in cleaned


def test_strip_comments_preserves_quoted_strings():
    text = 'name[Group1]="Not // a comment";'
    cleaned = strip_comments(text)
    assert cleaned.strip() == text.strip()


# --- multi-variant block extraction -----------------------------------------

def test_us_symbols_file_has_many_variants():
    variants = list_variants_in_symbols_text(read_symbols("us"))
    assert "basic" in variants
    assert "dvorak" in variants
    assert "colemak" in variants
    assert len(variants) > 20  # the real file defines 50+


def test_fr_symbols_file_has_many_variants():
    variants = list_variants_in_symbols_text(read_symbols("fr"))
    assert "basic" in variants
    assert "azerty" in variants
    assert "bepo" in variants
    assert len(variants) > 15


def test_default_variant_detection_picks_basic_for_us():
    parsed = parse_symbols(read_symbols("us"))
    assert parsed["variant"] == "basic"
    assert parsed["description"] == "English (US)"


def test_explicit_variant_selection():
    parsed = parse_symbols(read_symbols("us"), variant="dvorak")
    assert parsed["variant"] == "dvorak"
    # Dvorak's AD01 (where Q is on QWERTY) should NOT be 'q' -- Dvorak
    # rearranges the alphabetic keys.
    ad01 = parsed["keys"].get("AD01")
    assert ad01 is not None
    assert ad01.levels[0] != "q"


def test_requesting_unknown_variant_raises_keyerror():
    with pytest.raises(KeyError):
        parse_symbols(read_symbols("us"), variant="not_a_real_variant_xyz")


# --- real key data sanity checks --------------------------------------------

def test_us_basic_ae01_is_1_exclam():
    parsed = parse_symbols(read_symbols("us"), variant="basic")
    assert parsed["keys"]["AE01"].levels == ["1", "exclam"]


def test_fr_basic_ae01_is_ampersand_first():
    # French AZERTY-family layouts put digits on the shifted level.
    parsed = parse_symbols(read_symbols("fr"), variant="basic")
    assert parsed["keys"]["AE01"].levels[0] == "ampersand"
    assert parsed["keys"]["AE01"].levels[1] == "1"


def test_fr_basic_captures_four_level_keys():
    parsed = parse_symbols(read_symbols("fr"), variant="basic")
    # key <AE09> { [ ccedilla, 9, asciicircum, plusminus ] };
    assert parsed["keys"]["AE09"].levels == ["ccedilla", "9", "asciicircum", "plusminus"]


def test_comment_after_key_definition_does_not_corrupt_parsing():
    # Real fr file: key <AB08> {...}; // bullet
    parsed = parse_symbols(read_symbols("fr"), variant="basic")
    assert "AB08" in parsed["keys"]
    assert all(sym and "bullet" not in sym for sym in parsed["keys"]["AB08"].levels)


def test_key_type_attribute_lines_do_not_break_parsing():
    # Files using key.type[group1]="EIGHT_LEVEL"; as a standalone statement
    # (e.g. 'ca') must not confuse the key-definition regex.
    if not os.path.isfile(os.path.join(XKB_SYMBOLS_DIR, "ca")):
        pytest.skip("'ca' symbols file not present on this system")
    parsed = parse_symbols(read_symbols("ca"))
    assert len(parsed["keys"]) > 0
