#!/usr/bin/env bash
# File: test.sh
# Run this in a CI pipeline (or manually) to verify script integrity
# before deploying to a real system.

echo "Running CI Validation Tests..."
FAILED=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Check syntax of all bash scripts
for script in install.sh uninstall.sh modules/*.sh; do
    if bash -n "$script"; then
        echo "[PASS] Syntax check: $script"
    else
        echo "[FAIL] Syntax error in $script"
        FAILED=1
    fi
done

# 2. Check XML validity of the rules stub
if command -v xmllint >/dev/null 2>&1; then
    if echo "<root>$(cat rules)</root>" | xmllint --noout - 2>/dev/null; then
        echo "[PASS] XML rules format is valid"
    else
        echo "[FAIL] XML rules format is invalid"
        FAILED=1
    fi
else
    echo "[SKIP] xmllint not found, skipping XML validation."
fi

# 3. Check that every required file/module is present
for f in fr_custom rules VERSION \
         modules/common.sh modules/debian.sh modules/fedora.sh modules/arch.sh \
         modules/gnome.sh modules/kde.sh modules/xfce.sh; do
    if [[ -f "$f" ]]; then
        echo "[PASS] Found: $f"
    else
        echo "[FAIL] Missing: $f"
        FAILED=1
    fi
done

# 4. Verify layout conflict handling using temporary fixture files.
CONFLICT_TEST_DIR=$(mktemp -d)
if [[ -z "$CONFLICT_TEST_DIR" ]]; then
    echo "[FAIL] Could not create a temporary conflict-test directory"
    FAILED=1
else
    if (
        cd "$CONFLICT_TEST_DIR" || exit 1
        source "$SCRIPT_DIR/modules/common.sh"

        mkdir -p symbols
        : > rules.xml
        if ! check_layout_conflicts "fr_custom" \
            "$CONFLICT_TEST_DIR/symbols/fr_custom" \
            "$CONFLICT_TEST_DIR/rules.xml" \
            "$CONFLICT_TEST_DIR/installed.version"; then
            exit 1
        fi

        : > "$CONFLICT_TEST_DIR/symbols/fr_custom"
        if check_layout_conflicts "fr_custom" \
            "$CONFLICT_TEST_DIR/symbols/fr_custom" \
            "$CONFLICT_TEST_DIR/rules.xml" \
            "$CONFLICT_TEST_DIR/installed.version"; then
            exit 1
        fi
        rm -f "$CONFLICT_TEST_DIR/symbols/fr_custom"

        printf '<layout><name>fr_custom</name></layout>\n' \
            > "$CONFLICT_TEST_DIR/rules.xml"
        if check_layout_conflicts "fr_custom" \
            "$CONFLICT_TEST_DIR/symbols/fr_custom" \
            "$CONFLICT_TEST_DIR/rules.xml" \
            "$CONFLICT_TEST_DIR/installed.version"; then
            exit 1
        fi

        : > "$CONFLICT_TEST_DIR/symbols/fr_custom"
        : > "$CONFLICT_TEST_DIR/installed.version"
        if ! check_layout_conflicts "fr_custom" \
            "$CONFLICT_TEST_DIR/symbols/fr_custom" \
            "$CONFLICT_TEST_DIR/rules.xml" \
            "$CONFLICT_TEST_DIR/installed.version"; then
            exit 1
        fi
    ); then
        echo "[PASS] Layout conflicts reject unmanaged files and allow managed reinstall"
    else
        echo "[FAIL] Layout conflict handling"
        FAILED=1
    fi
    rm -rf "$CONFLICT_TEST_DIR"
fi

if [[ "$FAILED" == "1" ]]; then
    echo "One or more tests FAILED."
    exit 1
fi

echo "All tests passed successfully!"
