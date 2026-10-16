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

# 4. Verify backup preservation and layout conflict handling using fixtures.
STATE_TEST_DIR=$(mktemp -d)
if [[ -z "$STATE_TEST_DIR" ]]; then
    echo "[FAIL] Could not create a temporary state-test directory"
    FAILED=1
else
    if (
        cd "$STATE_TEST_DIR" || exit 1
        source "$SCRIPT_DIR/modules/common.sh"
        source "$SCRIPT_DIR/modules/gnome.sh"
        DRY_RUN=0
        INSTALL_STATE_DIR="$STATE_TEST_DIR/installer-state"
        INSTALL_TRANSACTION_DIR="$STATE_TEST_DIR/transaction"
        XKB_SYMBOLS_DIR="$STATE_TEST_DIR/system/symbols"
        XKB_RULES_DIR="$STATE_TEST_DIR/system/rules"
        EVDEV_XML="$XKB_RULES_DIR/evdev.xml"
        INSTALLED_VERSION_FILE="$XKB_SYMBOLS_DIR/fr_custom.version"
        TEST_HOME="$STATE_TEST_DIR/user-home"
        TEST_USER="$(id -un)"
        mkdir -p "$XKB_SYMBOLS_DIR" "$XKB_RULES_DIR"
        printf 'original symbols\n' > "$XKB_SYMBOLS_DIR/fr_custom"
        printf '<root>original rules</root>\n' > "$EVDEV_XML"
        rm -f "$INSTALLED_VERSION_FILE"
        mkdir -p "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
        clear_xkb_cache() {
            :
        }

        user_home_directory() {
            printf '%s\n' "$TEST_HOME"
        }

        su() {
            [[ "$1" == "-" && "$2" == "$TEST_USER" && "$3" == "-c" ]] || return 1
            eval "$4"
        }

        gsettings() {
            if [[ "$1" == "get" ]]; then
                printf "%s\n" "[('xkb', 'us'), ('xkb', 'us+intl')]"
            elif [[ "$1" == "set" ]]; then
                printf '%s\n' "$4" > "$STATE_TEST_DIR/gnome-restored-sources"
            else
                return 1
            fi
        }

        qdbus() {
            return 0
        }

        printf 'original system state\n' > managed.conf
        backup_file "$STATE_TEST_DIR/managed.conf"
        printf 'first installed state\n' > managed.conf
        backup_file "$STATE_TEST_DIR/managed.conf"
        if [[ "$(cat managed.conf.bak_fr_custom)" != "original system state" ]]; then
            exit 1
        fi

        printf 'originally absent\n' > absent.conf.bak_fr_custom.absent
        printf 'installed state\n' > absent.conf
        backup_file "$STATE_TEST_DIR/absent.conf"
        if [[ ! -f absent.conf.bak_fr_custom.absent || -e absent.conf.bak_fr_custom ]]; then
            exit 1
        fi

        printf 'original user configuration\n' > user.conf
        snapshot_state_file "$STATE_TEST_DIR/user.conf" "desktop-config"
        printf 'changed configuration\n' > user.conf
        snapshot_state_file "$STATE_TEST_DIR/user.conf" "desktop-config"
        if [[ "$(cat "${INSTALL_STATE_DIR}/desktop-config")" != "original user configuration" ]]; then
            exit 1
        fi
        restore_state_file "${INSTALL_STATE_DIR}/desktop-config" \
            "$STATE_TEST_DIR/user.conf"
        if [[ "$(cat "$STATE_TEST_DIR/user.conf")" != "original user configuration" ]]; then
            exit 1
        fi

        snapshot_state_file "$STATE_TEST_DIR/initially-absent.conf" "absent-config"
        : > "$STATE_TEST_DIR/initially-absent.conf"
        restore_state_file "${INSTALL_STATE_DIR}/absent-config" \
            "$STATE_TEST_DIR/initially-absent.conf"
        if [[ -e "$STATE_TEST_DIR/initially-absent.conf" ]]; then
            exit 1
        fi

        snapshot_desktop_state "$TEST_USER" "gnome"
        ACTUAL_USER="$TEST_USER"
        configure_gnome
        restore_desktop_state
        if [[ "$(cat "$STATE_TEST_DIR/gnome-restored-sources")" != \
            "[('xkb', 'us'), ('xkb', 'us+intl')]" ]]; then
            exit 1
        fi

        printf '[Layout]\nLayoutList=us\nVariantList=\n' \
            > "$TEST_HOME/.config/kxkbrc"
        snapshot_desktop_state "$TEST_USER" "kde"
        printf '[Layout]\nLayoutList=fr_custom\nVariantList=custom\n' \
            > "$TEST_HOME/.config/kxkbrc"
        restore_desktop_state
        if [[ "$(cat "$TEST_HOME/.config/kxkbrc")" != \
            $'[Layout]\nLayoutList=us\nVariantList=' ]]; then
            exit 1
        fi

        printf '<channel name="keyboard-layout"><property name="Default/XkbLayout" value="us"/></channel>\n' \
            > "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml"
        snapshot_desktop_state "$TEST_USER" "xfce"
        printf '<channel name="keyboard-layout"><property name="Default/XkbLayout" value="fr_custom"/></channel>\n' \
            > "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml"
        restore_desktop_state
        if [[ "$(cat "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml")" != \
            '<channel name="keyboard-layout"><property name="Default/XkbLayout" value="us"/></channel>' ]]; then
            exit 1
        fi

        rm -f "$TEST_HOME/.config/kxkbrc"
        snapshot_desktop_state "$TEST_USER" "kde"
        : > "$TEST_HOME/.config/kxkbrc"
        restore_desktop_state
        if [[ -e "$TEST_HOME/.config/kxkbrc" ]]; then
            exit 1
        fi

        snapshot_install_transaction "unknown" "fallback" "$TEST_USER"
        printf 'partially installed symbols\n' > "$XKB_SYMBOLS_DIR/fr_custom"
        printf '<root>partially changed rules</root>\n' > "$EVDEV_XML"
        printf '2.0\n' > "$INSTALLED_VERSION_FILE"
        printf 'new backup\n' > "$XKB_SYMBOLS_DIR/fr_custom.bak_fr_custom"
        recover_incomplete_installation
        if [[ "$(cat "$XKB_SYMBOLS_DIR/fr_custom")" != "original symbols" ||
              "$(cat "$EVDEV_XML")" != '<root>original rules</root>' ||
              -e "$INSTALLED_VERSION_FILE" ||
              -e "$XKB_SYMBOLS_DIR/fr_custom.bak_fr_custom" ||
              -e "$INSTALL_TRANSACTION_DIR/active" ]]; then
            exit 1
        fi
        if safe_exec "Expected failure fixture" false; then
            exit 1
        fi

        mkdir -p symbols
        : > rules.xml
        if ! check_layout_conflicts "fr_custom" \
            "$STATE_TEST_DIR/symbols/fr_custom" \
            "$STATE_TEST_DIR/rules.xml" \
            "$STATE_TEST_DIR/installed.version"; then
            exit 1
        fi

        : > "$STATE_TEST_DIR/symbols/fr_custom"
        if check_layout_conflicts "fr_custom" \
            "$STATE_TEST_DIR/symbols/fr_custom" \
            "$STATE_TEST_DIR/rules.xml" \
            "$STATE_TEST_DIR/installed.version"; then
            exit 1
        fi
        rm -f "$STATE_TEST_DIR/symbols/fr_custom"

        printf '<layout><name>fr_custom</name></layout>\n' \
            > "$STATE_TEST_DIR/rules.xml"
        if check_layout_conflicts "fr_custom" \
            "$STATE_TEST_DIR/symbols/fr_custom" \
            "$STATE_TEST_DIR/rules.xml" \
            "$STATE_TEST_DIR/installed.version"; then
            exit 1
        fi

        : > "$STATE_TEST_DIR/symbols/fr_custom"
        : > "$STATE_TEST_DIR/installed.version"
        if ! check_layout_conflicts "fr_custom" \
            "$STATE_TEST_DIR/symbols/fr_custom" \
            "$STATE_TEST_DIR/rules.xml" \
            "$STATE_TEST_DIR/installed.version"; then
            exit 1
        fi
    ); then
        echo "[PASS] Backups preserve first-install state across reinstalls"
        echo "[PASS] Originally absent files retain their absent-state marker"
        echo "[PASS] Saved configuration restores original contents and absence"
        echo "[PASS] GNOME, KDE, and XFCE settings restore to their captured state"
        echo "[PASS] Incomplete install transactions restore original files"
        echo "[PASS] Required command failures are returned to the installer"
        echo "[PASS] Layout conflicts reject unmanaged files and allow managed reinstall"
    else
        echo "[FAIL] Installer state and conflict handling"
        FAILED=1
    fi
    rm -rf "$STATE_TEST_DIR"
fi

if [[ "$FAILED" == "1" ]]; then
    echo "One or more tests FAILED."
    exit 1
fi

echo "All tests passed successfully!"
