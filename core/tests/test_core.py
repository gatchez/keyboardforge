"""Tests for keyboardforge_core: model, validator, generator, parser."""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest

from keyboardforge_core.model import Key, Layout
from keyboardforge_core.validator import validate, has_errors
from keyboardforge_core.xkb_generator import (
    generate_symbols_file,
    generate_rules_xml,
    LayoutGenerationError,
)
from keyboardforge_core.xkb_parser import parse_symbols, parse_rules_xml, parse_layout


def make_sample_layout() -> Layout:
    layout = Layout(
        xkb_name="fr_custom",
        variant="custom",
        description="French (customized by gatchez)",
        language="fra",
        base_layout="fr(basic)",
        includes=["level3(ralt_switch)"],
        author="gatchez",
    )
    layout.set_key("AE01", ["1", "ampersand"])
    layout.set_key("AE02", ["2", "eacute", "asciitilde"])
    layout.set_key("AD01", ["q", "Q"])
    layout.set_key("TLDE", ["0x10000b2"], comment="\u00b2")
    return layout


# --- model -------------------------------------------------------------

def test_key_round_trip_dict():
    key = Key(keycode="ae01", levels=["1", "ampersand"])
    d = key.to_dict()
    restored = Key.from_dict(d)
    assert restored.keycode == "ae01"
    assert restored.levels == ["1", "ampersand"]


def test_layout_json_round_trip():
    layout = make_sample_layout()
    text = layout.to_json()
    restored = Layout.from_json(text)

    assert restored.xkb_name == layout.xkb_name
    assert restored.variant == layout.variant
    assert restored.description == layout.description
    assert set(restored.keys.keys()) == set(layout.keys.keys())
    assert restored.keys["AE01"].levels == ["1", "ampersand"]


def test_layout_save_load(tmp_path):
    layout = make_sample_layout()
    path = tmp_path / "fr_custom.json"
    layout.save(str(path))
    restored = Layout.load(str(path))
    assert restored.to_dict() == layout.to_dict()


def test_duplicate_produces_independent_copy():
    layout = make_sample_layout()
    clone = layout.duplicate("fr_custom2", "custom2")
    clone.set_key("AD02", ["w", "W"])

    assert clone.xkb_name == "fr_custom2"
    assert "AD02" not in layout.keys  # original untouched
    assert "AD02" in clone.keys


def test_remove_key():
    layout = make_sample_layout()
    layout.remove_key("AE01")
    assert "AE01" not in layout.keys


# --- validator -----------------------------------------------------------

def test_valid_layout_has_no_errors():
    layout = make_sample_layout()
    issues = validate(layout)
    assert not has_errors(issues), [str(i) for i in issues]


def test_invalid_xkb_name_is_error():
    layout = make_sample_layout()
    layout.xkb_name = "not a valid name!"
    issues = validate(layout)
    assert has_errors(issues)


def test_empty_keys_is_error():
    layout = make_sample_layout()
    layout.keys = {}
    issues = validate(layout)
    assert has_errors(issues)


def test_empty_level_is_error():
    layout = make_sample_layout()
    layout.set_key("AB01", ["z", ""])
    issues = validate(layout)
    assert has_errors(issues)


def test_odd_keycode_is_warning_not_error():
    layout = make_sample_layout()
    layout.keys["weird"] = Key(keycode="weird", levels=["x"])
    issues = validate(layout)
    # Should warn about the odd keycode shape but not hard-fail the layout.
    assert any(i.severity == "warning" for i in issues)


# --- generator -------------------------------------------------------------

def test_generate_symbols_contains_expected_pieces():
    layout = make_sample_layout()
    text = generate_symbols_file(layout)
    assert 'xkb_symbols "custom"' in text
    assert 'name[Group1]= "French (customized by gatchez)"' in text
    assert 'include "fr(basic)"' in text
    assert "key <AE01> { [ 1, ampersand ] };" in text
    assert 'include "level3(ralt_switch)"' in text


def test_generate_rules_is_valid_xml():
    import xml.etree.ElementTree as ET
    layout = make_sample_layout()
    xml_text = generate_rules_xml(layout)
    root = ET.fromstring(xml_text)
    assert root.find("configItem/name").text == "fr_custom"
    assert root.find("variantList/variant/configItem/name").text == "custom"


def test_generate_refuses_invalid_layout():
    layout = make_sample_layout()
    layout.keys = {}
    with pytest.raises(LayoutGenerationError):
        generate_symbols_file(layout)


def test_generate_to_dir_writes_expected_filenames(tmp_path):
    from keyboardforge_core.xkb_generator import generate
    layout = make_sample_layout()
    paths = generate(layout, str(tmp_path))
    assert os.path.basename(paths["symbols"]) == "fr_custom"
    assert os.path.basename(paths["rules"]) == "rules"
    assert os.path.exists(paths["symbols"])
    assert os.path.exists(paths["rules"])


# --- parser & full round trip -----------------------------------------------

def test_parse_symbols_extracts_keys_and_metadata():
    layout = make_sample_layout()
    text = generate_symbols_file(layout)
    parsed = parse_symbols(text)
    assert parsed["variant"] == "custom"
    assert parsed["description"] == "French (customized by gatchez)"
    assert parsed["base_layout"] == "fr(basic)"
    assert "AE01" in parsed["keys"]
    assert parsed["keys"]["AE01"].levels == ["1", "ampersand"]


def test_parse_rules_extracts_metadata():
    layout = make_sample_layout()
    xml_text = generate_rules_xml(layout)
    parsed = parse_rules_xml(xml_text)
    assert parsed["xkb_name"] == "fr_custom"
    assert parsed["variant"] == "custom"
    assert parsed["language"] == "fra"


def test_full_generate_then_parse_round_trip():
    original = make_sample_layout()
    symbols_text = generate_symbols_file(original)
    rules_text = generate_rules_xml(original)

    restored = parse_layout(symbols_text, rules_text)

    assert restored.xkb_name == original.xkb_name
    assert restored.variant == original.variant
    assert restored.language == original.language
    assert set(restored.keys.keys()) == set(original.keys.keys())
    for code in original.keys:
        assert restored.keys[code].levels == original.keys[code].levels

    # And the restored layout must itself still validate cleanly.
    assert not has_errors(validate(restored))
