"""Tests for keyboardforge_core.system_layouts against the real,
OS-installed XKB layout tree. Gated on that tree actually being present.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest

from keyboardforge_core import system_layouts as sysl
from keyboardforge_core.validator import validate, has_errors

pytestmark = pytest.mark.skipif(
    not sysl.is_available(),
    reason="xkb-data not installed on this system",
)


def test_list_available_layouts_returns_real_entries():
    layouts = sysl.list_available_layouts()
    assert len(layouts) > 10
    names = {l["xkb_name"] for l in layouts}
    assert "us" in names
    assert "fr" in names


def test_get_layout_info_for_a_known_layout():
    info = sysl.get_layout_info("fr")
    assert info["description"] == "French"
    assert info["language"] == "fra"
    variant_names = {v["name"] for v in info["variants"]}
    assert "azerty" in variant_names


def test_get_layout_info_unknown_layout_raises():
    with pytest.raises(sysl.SystemLayoutError):
        sysl.get_layout_info("this_layout_does_not_exist_xyz")


def test_list_variants_matches_symbols_file_contents():
    variants = sysl.list_variants("fr")
    assert "basic" in variants
    assert "azerty" in variants
    assert len(variants) > 15


def test_import_basic_us_layout():
    layout = sysl.import_system_layout("us")
    assert layout.xkb_name == "us"
    assert layout.variant == "basic"
    assert layout.description == "English (US)"
    assert layout.language == "eng"
    assert layout.keys["AE01"].levels == ["1", "exclam"]
    assert not has_errors(validate(layout))


def test_import_with_explicit_variant():
    layout = sysl.import_system_layout("fr", variant="azerty")
    assert layout.variant == "azerty"
    assert "AZERTY" in layout.description
    assert not has_errors(validate(layout))


@pytest.mark.parametrize("xkb_name", ["de", "gb"])
def test_include_resolution_produces_a_complete_layout(xkb_name):
    """Regression test for the specific real-world problem this module
    exists to solve: 'de' and 'gb' both define their 'basic' variant
    almost entirely via `include`, so importing without resolving includes
    leaves most keys undefined. With resolve_includes=True (the default),
    the import must be complete."""
    resolved = sysl.import_system_layout(xkb_name, resolve_includes=True)
    unresolved = sysl.import_system_layout(xkb_name, resolve_includes=False)

    assert len(resolved.keys) > len(unresolved.keys)
    assert "AE01" in resolved.keys, f"{xkb_name}: AE01 should be present after include resolution"
    assert not has_errors(validate(resolved))


def test_unresolved_import_preserves_include_metadata():
    layout = sysl.import_system_layout("fr", variant="azerty", resolve_includes=False)
    # AZERTY variant includes fr(basic) -- confirm that's captured, not lost.
    assert layout.base_layout is not None or layout.includes


def test_resolved_import_has_no_dangling_include_metadata():
    layout = sysl.import_system_layout("fr", variant="azerty", resolve_includes=True)
    # Keys are fully flattened in, so there is nothing left to `include`.
    assert layout.base_layout is None
    assert layout.includes == []


def test_import_unknown_layout_raises():
    with pytest.raises(sysl.SystemLayoutError):
        sysl.import_system_layout("this_layout_does_not_exist_xyz")


def test_include_cycle_does_not_infinite_loop():
    # A synthetic pathological case: two files that include each other.
    # Not expected in real xkb-data, but the resolver must not hang if it
    # ever encounters one (e.g. a corrupted or hand-edited symbols tree).
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "aa"), "w") as f:
            f.write('xkb_symbols "basic" { include "bb(basic)" key <AE01> { [ a ] }; };')
        with open(os.path.join(tmp, "bb"), "w") as f:
            f.write('xkb_symbols "basic" { include "aa(basic)" key <AE02> { [ b ] }; };')

        # Should return promptly (cycle-protected), not hang.
        layout = sysl.import_system_layout("aa", symbols_dir=tmp, rules_xml="/nonexistent")
        assert "AE01" in layout.keys
