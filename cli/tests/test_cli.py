"""Tests for keyboardforge_cli."""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "core"))

import pytest

from keyboardforge_cli.cli import main


def run(argv):
    return main(argv)


def test_new_creates_layout(tmp_path, capsys):
    out = tmp_path / "test_layout.json"
    rc = run(["new", "test_custom", "custom", str(out), "--description", "Test Layout", "--language", "eng"])
    assert rc == 0
    assert out.exists()
    data = json.loads(out.read_text())
    assert data["xkb_name"] == "test_custom"
    assert data["variant"] == "custom"
    assert data["keys"] == []


def test_set_key_and_remove_key(tmp_path):
    out = tmp_path / "layout.json"
    run(["new", "test_custom", "custom", str(out)])

    rc = run(["set-key", str(out), "AE01", "1", "ampersand"])
    assert rc == 0
    data = json.loads(out.read_text())
    keys = {k["keycode"]: k["levels"] for k in data["keys"]}
    assert keys["AE01"] == ["1", "ampersand"]

    rc = run(["remove-key", str(out), "AE01"])
    assert rc == 0
    data = json.loads(out.read_text())
    assert data["keys"] == []


def test_validate_reports_errors_for_empty_layout(tmp_path, capsys):
    out = tmp_path / "empty.json"
    run(["new", "test_custom", "custom", str(out), "--description", "Empty"])
    rc = run(["validate", str(out)])
    assert rc == 1  # zero keys is a validation error
    captured = capsys.readouterr()
    assert "ERROR" in captured.out


def test_validate_passes_for_populated_layout(tmp_path):
    out = tmp_path / "ok.json"
    run(["new", "test_custom", "custom", str(out), "--description", "OK Layout"])
    run(["set-key", str(out), "AE01", "1", "ampersand"])
    rc = run(["validate", str(out)])
    assert rc == 0


def test_export_and_import_round_trip(tmp_path):
    layout_path = tmp_path / "layout.json"
    export_dir = tmp_path / "exported"
    export_dir.mkdir()

    run(["new", "rt_custom", "custom", str(layout_path), "--description", "Round Trip", "--language", "eng"])
    run(["set-key", str(layout_path), "AD01", "q", "Q"])

    rc = run(["export", str(layout_path), str(export_dir)])
    assert rc == 0
    assert (export_dir / "rt_custom").exists()
    assert (export_dir / "rules").exists()

    imported_path = tmp_path / "imported.json"
    rc = run([
        "import",
        str(export_dir / "rt_custom"),
        str(export_dir / "rules"),
        str(imported_path),
    ])
    assert rc == 0
    imported = json.loads(imported_path.read_text())
    assert imported["xkb_name"] == "rt_custom"
    keys = {k["keycode"]: k["levels"] for k in imported["keys"]}
    assert keys["AD01"] == ["q", "Q"]


def test_list_reports_layouts(tmp_path, capsys):
    d = tmp_path / "layouts"
    d.mkdir()
    run(["new", "a_custom", "custom", str(d / "a.json"), "--description", "A"])
    run(["set-key", str(d / "a.json"), "AE01", "1"])

    rc = run(["list", str(d)])
    assert rc == 0
    captured = capsys.readouterr()
    assert "a_custom" in captured.out


def test_list_empty_directory(tmp_path, capsys):
    d = tmp_path / "empty_dir"
    d.mkdir()
    rc = run(["list", str(d)])
    assert rc == 0
    captured = capsys.readouterr()
    assert "No layout JSON files found" in captured.out


# --- system layout detection & import (real OS data) ------------------------

XKB_SYMBOLS_DIR = "/usr/share/X11/xkb/symbols"

xkb_data_available = pytest.mark.skipif(
    not os.path.isdir(XKB_SYMBOLS_DIR),
    reason="xkb-data not installed on this system",
)


@xkb_data_available
def test_system_layouts_lists_real_layouts(capsys):
    rc = run(["system-layouts"])
    assert rc == 0
    captured = capsys.readouterr()
    assert "us:" in captured.out
    assert "fr:" in captured.out


@xkb_data_available
def test_system_layouts_with_name_lists_variants(capsys):
    rc = run(["system-layouts", "fr"])
    assert rc == 0
    captured = capsys.readouterr()
    assert "azerty" in captured.out


@xkb_data_available
def test_system_layouts_unknown_name_errors(capsys):
    rc = run(["system-layouts", "not_a_real_layout_xyz"])
    assert rc == 1


@xkb_data_available
def test_import_system_produces_valid_layout(tmp_path):
    out = tmp_path / "us_imported.json"
    rc = run(["import-system", "us", str(out)])
    assert rc == 0
    data = json.loads(out.read_text())
    assert data["xkb_name"] == "us"
    assert data["variant"] == "basic"
    keys = {k["keycode"]: k["levels"] for k in data["keys"]}
    assert keys["AE01"] == ["1", "exclam"]

    # And it must pass keyboardforge's own validator.
    rc = run(["validate", str(out)])
    assert rc == 0


@xkb_data_available
def test_import_system_with_variant(tmp_path):
    out = tmp_path / "fr_azerty.json"
    rc = run(["import-system", "fr", str(out), "--variant", "azerty"])
    assert rc == 0
    data = json.loads(out.read_text())
    assert data["variant"] == "azerty"


@xkb_data_available
def test_import_system_include_resolution_is_complete_for_gb(tmp_path):
    """Regression test: 'gb' defines its basic variant almost entirely via
    `include`; a naive single-block import used to leave it nearly empty."""
    out = tmp_path / "gb.json"
    run(["import-system", "gb", str(out)])
    data = json.loads(out.read_text())
    keys = {k["keycode"] for k in data["keys"]}
    assert "AE01" in keys
    assert len(keys) > 30


@xkb_data_available
def test_import_system_unknown_layout_errors():
    rc = run(["import-system", "not_a_real_layout_xyz", "/tmp/whatever.json"])
    assert rc == 1


# --- real (but safe) integration with the linux/ installer -------------------

LINUX_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "linux")


@pytest.mark.skipif(not os.path.isdir(LINUX_DIR), reason="linux/ installer not present in this snapshot")
@pytest.mark.skipif(os.geteuid() != 0, reason="installer requires root")
def test_cli_install_dry_run_against_real_linux_dir(tmp_path):
    """Exercises the real `keyboardforge install --dry-run` path end-to-end
    against a throwaway copy of the actual linux/ installer, and asserts it
    makes zero real filesystem changes (dry-run must stay inert). Uses a
    copy rather than the real linux/ directory because `install` always
    (re)generates fr_custom/rules into --linux-dir -- even during a system
    dry-run -- and this test must not overwrite the shipped layout files."""
    import hashlib
    import shutil

    linux_copy = tmp_path / "linux_copy"
    shutil.copytree(LINUX_DIR, linux_copy)

    evdev_xml = "/usr/share/X11/xkb/rules/evdev.xml"
    before_hash = None
    if os.path.isfile(evdev_xml):
        before_hash = hashlib.md5(open(evdev_xml, "rb").read()).hexdigest()

    layout_path = tmp_path / "fr_custom.json"
    run(["new", "fr_custom", "custom", str(layout_path), "--description", "Test", "--language", "fra"])
    run(["set-key", str(layout_path), "AE01", "1", "ampersand"])

    rc = run(["install", str(layout_path), "--linux-dir", str(linux_copy), "--dry-run", "--yes"])
    assert rc == 0

    if before_hash is not None:
        after_hash = hashlib.md5(open(evdev_xml, "rb").read()).hexdigest()
        assert before_hash == after_hash, "dry-run must not modify evdev.xml"
