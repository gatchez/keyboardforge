#!/usr/bin/env python3
"""tools/generate_layout.py

Build step that turns a KeyboardForge JSON layout definition into the two
files the Linux installer expects to find in its working directory: the
XKB symbols file (named after the layout's xkb_name) and the "rules" XML
stub.

Usage:
    python3 tools/generate_layout.py layouts/fr_custom.json linux/

Validates the layout first and refuses to write anything if there are
validation errors (warnings are printed but don't block generation).
"""

import argparse
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "core"))

from keyboardforge_core.model import Layout
from keyboardforge_core.validator import validate, has_errors
from keyboardforge_core.xkb_generator import generate, LayoutGenerationError


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("layout_json", help="Path to a KeyboardForge layout JSON file")
    parser.add_argument("output_dir", help="Directory to write the generated XKB files into")
    args = parser.parse_args()

    if not os.path.isfile(args.layout_json):
        print(f"ERROR: layout file not found: {args.layout_json}", file=sys.stderr)
        return 1

    layout = Layout.load(args.layout_json)

    issues = validate(layout)
    for issue in issues:
        stream = sys.stderr if issue.severity == "error" else sys.stdout
        print(str(issue), file=stream)

    if has_errors(issues):
        print(f"\nRefusing to generate: '{args.layout_json}' has validation errors.", file=sys.stderr)
        return 1

    if not os.path.isdir(args.output_dir):
        print(f"ERROR: output directory not found: {args.output_dir}", file=sys.stderr)
        return 1

    try:
        paths = generate(layout, args.output_dir)
    except LayoutGenerationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Generated symbols file: {paths['symbols']}")
    print(f"Generated rules file:   {paths['rules']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
