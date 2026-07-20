"""keyboardforge_cli.cli

The `keyboardforge` command. Run `keyboardforge --help` for the full list
of subcommands, or see docs/cli-manual.md.
"""

from __future__ import annotations

import argparse
import glob
import os
import subprocess
import sys
from pathlib import Path

# Make keyboardforge_core importable regardless of how this CLI is invoked
# (as an installed package, or straight out of the repo checkout).
_REPO_ROOT = Path(__file__).resolve().parents[2]
_CORE_SRC = _REPO_ROOT / "core"
if str(_CORE_SRC) not in sys.path and _CORE_SRC.is_dir():
    sys.path.insert(0, str(_CORE_SRC))

from keyboardforge_core.model import Layout  # noqa: E402
from keyboardforge_core.validator import validate, has_errors  # noqa: E402
from keyboardforge_core.xkb_generator import generate, LayoutGenerationError  # noqa: E402
from keyboardforge_core.xkb_parser import parse_layout  # noqa: E402
from keyboardforge_core import system_layouts as sysl  # noqa: E402

DEFAULT_LINUX_DIR = str(_REPO_ROOT / "linux")


# --- subcommand implementations -------------------------------------------

def cmd_new(args) -> int:
    layout = Layout(
        xkb_name=args.xkb_name,
        variant=args.variant,
        description=args.description,
        language=args.language,
        base_layout=args.base,
    )
    layout.save(args.output)
    print(f"Created new layout '{args.xkb_name}' ({args.variant}) -> {args.output}")
    return 0


def cmd_set_key(args) -> int:
    layout = Layout.load(args.layout)
    layout.set_key(args.keycode, args.levels, comment=args.comment)
    layout.save(args.layout)
    print(f"Set {args.keycode.upper()} = [{', '.join(args.levels)}] in {args.layout}")
    return 0


def cmd_remove_key(args) -> int:
    layout = Layout.load(args.layout)
    layout.remove_key(args.keycode)
    layout.save(args.layout)
    print(f"Removed {args.keycode.upper()} from {args.layout}")
    return 0


def cmd_validate(args) -> int:
    layout = Layout.load(args.layout)
    issues = validate(layout)
    for issue in issues:
        print(str(issue))
    if has_errors(issues):
        print(f"\n{args.layout}: INVALID")
        return 1
    print(f"\n{args.layout}: valid" + (f" ({len(issues)} warning(s))" if issues else ""))
    return 0


def cmd_export(args) -> int:
    layout = Layout.load(args.layout)
    try:
        paths = generate(layout, args.output_dir)
    except LayoutGenerationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"Exported symbols file: {paths['symbols']}")
    print(f"Exported rules file:   {paths['rules']}")
    return 0


def cmd_import(args) -> int:
    with open(args.symbols_file, "r", encoding="utf-8") as f:
        symbols_text = f.read()
    with open(args.rules_file, "r", encoding="utf-8") as f:
        rules_text = f.read()
    layout = parse_layout(symbols_text, rules_text, variant=args.variant)
    layout.save(args.output)
    print(f"Imported '{layout.xkb_name}' ({len(layout.keys)} keys) -> {args.output}")
    return 0


def cmd_system_layouts(args) -> int:
    if not sysl.is_available(args.symbols_dir):
        print(f"No XKB layout data found at {args.symbols_dir}.", file=sys.stderr)
        print("On Linux this is provided by the 'xkb-data' package -- "
              "install it, or point --symbols-dir/--rules-xml elsewhere.", file=sys.stderr)
        return 1

    if args.xkb_name:
        try:
            info = sysl.get_layout_info(args.xkb_name, args.rules_xml)
        except sysl.SystemLayoutError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1
        print(f"{info['xkb_name']}: {info['description']} ({info['language']})")
        try:
            physical_variants = sysl.list_variants(args.xkb_name, args.symbols_dir)
        except sysl.SystemLayoutError:
            physical_variants = []
        described = {v["name"]: v["description"] for v in info["variants"]}
        all_variants = sorted(set(described) | set(physical_variants))
        if not all_variants:
            print("  (no variants found -- this layout may only have a 'basic' block)")
        for v in all_variants:
            desc = described.get(v, "(no evdev.xml description -- see symbols file directly)")
            print(f"  {v}: {desc}")
        return 0

    try:
        layouts = sysl.list_available_layouts(args.rules_xml)
    except sysl.SystemLayoutError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    for entry in layouts:
        print(f"{entry['xkb_name']}: {entry['description']} ({entry['language']}) "
              f"-- {len(entry['variants'])} variant(s)")
    print(f"\n{len(layouts)} layout(s) total. "
          f"Use 'keyboardforge system-layouts <xkb_name>' to list one's variants.")
    return 0


def cmd_import_system(args) -> int:
    if not sysl.is_available(args.symbols_dir):
        print(f"No XKB layout data found at {args.symbols_dir}.", file=sys.stderr)
        return 1
    try:
        layout = sysl.import_system_layout(
            args.xkb_name,
            variant=args.variant,
            symbols_dir=args.symbols_dir,
            rules_xml=args.rules_xml,
            resolve_includes=not args.no_resolve_includes,
        )
    except sysl.SystemLayoutError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    layout.save(args.output)
    issues = validate(layout)
    for issue in issues:
        print(str(issue))
    print(f"Imported system layout '{args.xkb_name}' variant '{layout.variant}' "
          f"({len(layout.keys)} keys) -> {args.output}")
    if args.no_resolve_includes:
        print("(--no-resolve-includes was set: only this variant's own locally-defined "
              "keys were imported; anything it pulls in via `include` was left out.)")
    return 0


def cmd_list(args) -> int:
    pattern = os.path.join(args.directory, "*.json")
    found = sorted(glob.glob(pattern))
    if not found:
        print(f"No layout JSON files found in {args.directory}")
        return 0
    for path in found:
        try:
            layout = Layout.load(path)
            issues = validate(layout)
            status = "INVALID" if has_errors(issues) else "valid"
            print(f"{path}\n  {layout.xkb_name} ({layout.variant}) -- "
                  f"\"{layout.description}\" [{status}, {len(layout.keys)} keys]")
        except Exception as exc:  # noqa: BLE001 -- surfacing bad files is the point
            print(f"{path}\n  ERROR: could not read as a layout: {exc}")
    return 0


def cmd_install(args) -> int:
    layout = Layout.load(args.layout)
    issues = validate(layout)
    for issue in issues:
        print(str(issue))
    if has_errors(issues):
        print("Refusing to install: layout has validation errors.", file=sys.stderr)
        return 1

    try:
        generate(layout, args.linux_dir)
    except LayoutGenerationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    install_script = os.path.join(args.linux_dir, "install.sh")
    if not os.path.isfile(install_script):
        print(f"ERROR: {install_script} not found.", file=sys.stderr)
        return 1

    cmd = ["sudo", install_script] if os.geteuid() != 0 else [install_script]
    if args.dry_run:
        cmd.append("--dry-run")
    if args.yes:
        cmd.append("--yes")

    print(f"Running: {' '.join(cmd)} (cwd={args.linux_dir})")
    result = subprocess.run(cmd, cwd=args.linux_dir)
    return result.returncode


def cmd_uninstall(args) -> int:
    uninstall_script = os.path.join(args.linux_dir, "uninstall.sh")
    if not os.path.isfile(uninstall_script):
        print(f"ERROR: {uninstall_script} not found.", file=sys.stderr)
        return 1
    cmd = ["sudo", uninstall_script] if os.geteuid() != 0 else [uninstall_script]
    print(f"Running: {' '.join(cmd)} (cwd={args.linux_dir})")
    result = subprocess.run(cmd, cwd=args.linux_dir)
    return result.returncode


# --- argument parser --------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="keyboardforge",
        description="Create, edit, validate, and install custom keyboard layouts.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("new", help="Create a new, empty layout JSON file.")
    p.add_argument("xkb_name", help="XKB identifier, e.g. 'fr_custom'")
    p.add_argument("variant", help="XKB variant name, e.g. 'custom'")
    p.add_argument("output", help="Path to write the layout JSON to")
    p.add_argument("--description", default="", help="Human-readable name shown in DE keyboard pickers")
    p.add_argument("--language", default="eng", help="ISO 639 language code (default: eng)")
    p.add_argument("--base", default=None, help="Base layout to include, e.g. 'us(basic)'")
    p.set_defaults(func=cmd_new)

    p = sub.add_parser("set-key", help="Set (or overwrite) a single key's levels.")
    p.add_argument("layout", help="Path to a layout JSON file")
    p.add_argument("keycode", help="XKB keycode, e.g. AE01")
    p.add_argument("levels", nargs="+", help="Symbol per shift level, e.g. 1 ampersand")
    p.add_argument("--comment", default=None)
    p.set_defaults(func=cmd_set_key)

    p = sub.add_parser("remove-key", help="Remove a key from a layout.")
    p.add_argument("layout")
    p.add_argument("keycode")
    p.set_defaults(func=cmd_remove_key)

    p = sub.add_parser("validate", help="Validate a layout JSON file.")
    p.add_argument("layout")
    p.set_defaults(func=cmd_validate)

    p = sub.add_parser("export", help="Generate XKB symbols + rules files from a layout JSON.")
    p.add_argument("layout")
    p.add_argument("output_dir")
    p.set_defaults(func=cmd_export)

    p = sub.add_parser("import", help="Parse existing XKB symbols + rules files into a layout JSON.")
    p.add_argument("symbols_file")
    p.add_argument("rules_file")
    p.add_argument("output")
    p.add_argument("--variant", default=None,
                    help="Which xkb_symbols block to use if symbols_file defines more than one "
                         "(default: the file's 'default'-marked block, else 'basic', else the first found)")
    p.set_defaults(func=cmd_import)

    p = sub.add_parser(
        "system-layouts",
        help="List keyboard layouts installed by the OS itself (via xkb-data), "
             "or one layout's variants if given a name.",
    )
    p.add_argument("xkb_name", nargs="?", default=None,
                    help="Show variants for this specific layout instead of listing all layouts")
    p.add_argument("--symbols-dir", default=sysl.DEFAULT_XKB_SYMBOLS_DIR)
    p.add_argument("--rules-xml", default=sysl.DEFAULT_XKB_RULES_XML)
    p.set_defaults(func=cmd_system_layouts)

    p = sub.add_parser(
        "import-system",
        help="Import a real OS-installed layout (e.g. your system's actual 'fr' or 'us' "
             "layout) into a KeyboardForge layout JSON, ready for customization.",
    )
    p.add_argument("xkb_name", help="e.g. 'fr', 'us', 'de' -- see 'keyboardforge system-layouts'")
    p.add_argument("output", help="Path to write the imported layout JSON to")
    p.add_argument("--variant", default=None,
                    help="e.g. 'azerty', 'dvorak' (default: the layout's default/basic variant)")
    p.add_argument("--symbols-dir", default=sysl.DEFAULT_XKB_SYMBOLS_DIR)
    p.add_argument("--rules-xml", default=sysl.DEFAULT_XKB_RULES_XML)
    p.add_argument("--no-resolve-includes", action="store_true",
                    help="Import only this variant's own locally-defined keys, without pulling in "
                         "keys it inherits via `include` from other files (advanced; see docs/developer-guide.md)")
    p.set_defaults(func=cmd_import_system)

    p = sub.add_parser("list", help="List all layout JSON files in a directory.")
    p.add_argument("directory", nargs="?", default=str(_REPO_ROOT / "layouts"))
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("install", help="Generate + install a layout on this Linux system (needs root).")
    p.add_argument("layout")
    p.add_argument("--linux-dir", default=DEFAULT_LINUX_DIR, help="Path to the linux/ installer directory")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--yes", action="store_true", help="Skip the confirmation prompt")
    p.set_defaults(func=cmd_install)

    p = sub.add_parser("uninstall", help="Revert a previously installed layout (needs root).")
    p.add_argument("--linux-dir", default=DEFAULT_LINUX_DIR, help="Path to the linux/ installer directory")
    p.set_defaults(func=cmd_uninstall)

    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
