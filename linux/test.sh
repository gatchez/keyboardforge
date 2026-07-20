#!/usr/bin/env bash
# File: test.sh
# Run this in a CI pipeline (or manually) to verify script integrity
# before deploying to a real system.

echo "Running CI Validation Tests..."
FAILED=0

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

if [[ "$FAILED" == "1" ]]; then
    echo "One or more tests FAILED."
    exit 1
fi

echo "All tests passed successfully!"
