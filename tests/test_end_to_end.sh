#!/usr/bin/env bash
# File: tests/test_end_to_end.sh
#
# A genuine cross-component integration test, distinct from each
# component's own unit tests: takes layouts/fr_custom.json all the way
# through the real pipeline (core engine generation -> real linux/install.sh
# -> real linux/uninstall.sh) against a throwaway copy of the installer, and
# asserts the system's evdev.xml ends up byte-identical to where it started.
#
# Requires root and a supported OS marker (Debian/Fedora/Arch) to run the
# real install/uninstall portion; otherwise it verifies everything up to
# that point (generation + dry-run) and skips the rest with a clear message
# rather than failing, so this suite stays green in unsupported CI
# environments.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAIL=0
check() {
    if [[ "$2" == "0" ]]; then
        echo "[PASS] $1"
    else
        echo "[FAIL] $1"
        FAIL=1
    fi
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "=== Step 1: generate XKB files from layouts/fr_custom.json ==="
cp -r linux "$WORKDIR/linux"
rm -f "$WORKDIR/linux/fr_custom" "$WORKDIR/linux/rules"
python3 tools/generate_layout.py layouts/fr_custom.json "$WORKDIR/linux"
GEN_RC=$?
check "generate_layout.py produced fr_custom + rules" "$GEN_RC"
[[ -f "$WORKDIR/linux/fr_custom" ]]; check "generated fr_custom file exists" "$?"
[[ -f "$WORKDIR/linux/rules" ]]; check "generated rules file exists" "$?"

echo ""
echo "=== Step 2: linux/test.sh against the generated files ==="
( cd "$WORKDIR/linux" && chmod +x install.sh uninstall.sh test.sh modules/*.sh && ./test.sh > /dev/null )
check "linux/test.sh passes against generated fr_custom/rules" "$?"

echo ""
echo "=== Step 3: --dry-run install must make zero real filesystem changes ==="
EVDEV_XML="/usr/share/X11/xkb/rules/evdev.xml"
if [[ -f "$EVDEV_XML" ]]; then
    BEFORE=$(md5sum "$EVDEV_XML" | awk '{print $1}')
else
    BEFORE=""
fi
( cd "$WORKDIR/linux" && ./install.sh --dry-run --yes > /dev/null 2>&1 )
DRYRUN_RC=$?
check "dry-run install exits 0" "$DRYRUN_RC"
if [[ -f "$EVDEV_XML" ]]; then
    AFTER=$(md5sum "$EVDEV_XML" | awk '{print $1}')
else
    AFTER=""
fi
[[ "$BEFORE" == "$AFTER" ]]; check "dry-run left evdev.xml untouched" "$?"

echo ""
if [[ "$(id -u)" != "0" ]]; then
    echo "[SKIP] Real install/uninstall round trip -- not running as root."
elif [[ ! -f /etc/debian_version && ! -f /etc/fedora-release && ! -f /etc/arch-release ]]; then
    echo "[SKIP] Real install/uninstall round trip -- unsupported OS on this machine."
else
    echo "=== Step 4: REAL install + uninstall round trip (root confirmed) ==="
    ( cd "$WORKDIR/linux" && ./install.sh --yes > /dev/null 2>&1 )
    check "real install exits 0" "$?"
    [[ -f /usr/share/X11/xkb/symbols/fr_custom ]]; check "fr_custom installed to XKB_SYMBOLS_DIR" "$?"
    grep -q "<name>fr_custom</name>" "$EVDEV_XML" 2>/dev/null; check "evdev.xml contains the fr_custom entry" "$?"
    xmllint --noout "$EVDEV_XML" 2>/dev/null; check "evdev.xml is still valid XML after injection" "$?"

    ( cd "$WORKDIR/linux" && ./uninstall.sh > /dev/null 2>&1 )
    check "uninstall exits 0" "$?"
    [[ ! -f /usr/share/X11/xkb/symbols/fr_custom ]]; check "fr_custom removed after uninstall" "$?"

    if [[ -n "$BEFORE" ]]; then
        AFTER_UNINSTALL=$(md5sum "$EVDEV_XML" | awk '{print $1}')
        [[ "$BEFORE" == "$AFTER_UNINSTALL" ]]
        check "evdev.xml is byte-identical to baseline after full round trip" "$?"
    fi
fi

echo ""
if [[ "$FAIL" == "1" ]]; then
    echo "End-to-end test: ONE OR MORE CHECKS FAILED."
    exit 1
fi
echo "End-to-end test: all checks passed."
