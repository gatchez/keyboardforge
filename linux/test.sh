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

# 4. Verify --dry-run helpers do not create files, logs, or locks.
DRY_RUN_TEST_DIR=$(mktemp -d)
if [[ -z "$DRY_RUN_TEST_DIR" ]]; then
    echo "[FAIL] Could not create a temporary dry-run test directory"
    FAILED=1
else
    if (
        cd "$DRY_RUN_TEST_DIR" || exit 1
        DRY_RUN=1
        source "$SCRIPT_DIR/modules/common.sh"
        INSTALL_STATE_DIR="$DRY_RUN_TEST_DIR/state"
        INSTALL_TRANSACTION_DIR="$DRY_RUN_TEST_DIR/state/transaction"
        LOCK_DIR="$DRY_RUN_TEST_DIR/installer.lock"
        LOG_DIR="$DRY_RUN_TEST_DIR/logs"
        LOG_FILE="$LOG_DIR/install.log"

        [[ ! -e "$LOG_DIR" ]] || exit 1
        mkdir "$LOG_DIR"
        printf 'existing log must stay unchanged\n' > "$LOG_FILE"
        mkdir "$LOCK_DIR"
        printf 'existing lock must stay untouched\n' > "$LOCK_DIR/owner"
        log_info "Dry-run logging fixture"
        acquire_lock
        printf 'before\n' > source.conf
        backup_file "$DRY_RUN_TEST_DIR/source.conf"
        snapshot_state_file "$DRY_RUN_TEST_DIR/source.conf" "saved.conf"
        safe_exec "Dry-run command fixture" touch "$DRY_RUN_TEST_DIR/command-ran"
        snapshot_desktop_state "missing-user" "gnome"
        configure_desktop_integration
        clear_xkb_cache

        apt-get() { : > "$DRY_RUN_TEST_DIR/package-command-ran"; }
        dnf() { : > "$DRY_RUN_TEST_DIR/package-command-ran"; }
        pacman() { : > "$DRY_RUN_TEST_DIR/package-command-ran"; }
        source "$SCRIPT_DIR/modules/debian.sh"
        install_dependencies
        source "$SCRIPT_DIR/modules/fedora.sh"
        install_dependencies
        source "$SCRIPT_DIR/modules/arch.sh"
        install_dependencies

        [[ "$(cat "$LOG_FILE")" == "existing log must stay unchanged" &&
           "$(cat "$LOCK_DIR/owner")" == "existing lock must stay untouched" &&
           ! -e "$INSTALL_STATE_DIR" &&
           ! -e "$DRY_RUN_TEST_DIR/source.conf.bak_fr_custom" &&
           ! -e "$DRY_RUN_TEST_DIR/command-ran" &&
           ! -e "$DRY_RUN_TEST_DIR/package-command-ran" &&
           "$INTEGRATION_RESULT" == "simulated" ]]
    ); then
        echo "[PASS] Dry-run helpers do not write logs, locks, backups, state, or package changes"
    else
        echo "[FAIL] Dry-run caused a persistent filesystem or package-manager change"
        FAILED=1
    fi
    rm -rf "$DRY_RUN_TEST_DIR"
fi

# 5. Verify backup preservation and layout conflict handling using fixtures.
STATE_TEST_DIR=$(mktemp -d)
if [[ -z "$STATE_TEST_DIR" ]]; then
    echo "[FAIL] Could not create a temporary state-test directory"
    FAILED=1
else
    if (
        cd "$STATE_TEST_DIR" || exit 1
        source "$SCRIPT_DIR/modules/common.sh"
        source "$SCRIPT_DIR/modules/gnome.sh"
        source "$SCRIPT_DIR/modules/kde.sh"
        source "$SCRIPT_DIR/modules/xfce.sh"
        DRY_RUN=0
        INSTALL_STATE_DIR="$STATE_TEST_DIR/installer-state"
        INSTALL_TRANSACTION_DIR="$STATE_TEST_DIR/transaction"
        XKB_SYMBOLS_DIR="$STATE_TEST_DIR/system/symbols"
        XKB_RULES_DIR="$STATE_TEST_DIR/system/rules"
        EVDEV_XML="$XKB_RULES_DIR/evdev.xml"
        INSTALLED_VERSION_FILE="$XKB_SYMBOLS_DIR/fr_custom.version"
        TEST_HOME="$STATE_TEST_DIR/user-home"
        DEBIAN_KEYBOARD_FILE="$STATE_TEST_DIR/etc/default/keyboard"
        SYSTEM_X11_KEYBOARD_FILE="$STATE_TEST_DIR/etc/X11/xorg.conf.d/00-keyboard.conf"
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

        GNOME_CONFIG_IMPLEMENTATION="$(declare -f configure_gnome)"
        KDE_CONFIG_IMPLEMENTATION="$(declare -f configure_kde)"
        XFCE_CONFIG_IMPLEMENTATION="$(declare -f configure_xfce)"
        configure_gnome() { return "${GNOME_TEST_RESULT:-0}"; }
        configure_kde() { return "${KDE_TEST_RESULT:-0}"; }
        configure_xfce() { return "${XFCE_TEST_RESULT:-0}"; }

        DE="gnome"
        DISPLAY_SERVER="wayland"
        GNOME_TEST_RESULT=0
        configure_desktop_integration
        [[ "$INTEGRATION_RESULT" == "configured" ]] || exit 1

        GNOME_TEST_RESULT=1
        configure_desktop_integration
        [[ "$INTEGRATION_RESULT" == "failed" ]] || exit 1

        DE="xfce"
        DISPLAY_SERVER="wayland"
        configure_desktop_integration
        [[ "$INTEGRATION_RESULT" == "manual" ]] || exit 1

        DE="fallback"
        configure_desktop_integration
        [[ "$INTEGRATION_RESULT" == "manual" ]] || exit 1

        DRY_RUN=1
        DE="gnome"
        configure_desktop_integration
        [[ "$INTEGRATION_RESULT" == "simulated" ]] || exit 1
        DRY_RUN=0
        eval "$GNOME_CONFIG_IMPLEMENTATION"
        eval "$KDE_CONFIG_IMPLEMENTATION"
        eval "$XFCE_CONFIG_IMPLEMENTATION"

        printf 'original system state\n' > managed.conf
        backup_file "$STATE_TEST_DIR/managed.conf"
        printf 'first installed state\n' > managed.conf
        backup_file "$STATE_TEST_DIR/managed.conf"
        if [[ "$(cat managed.conf.bak_fr_custom)" != "original system state" ]]; then
            exit 1
        fi
        printf 'second installed state\n' > managed.conf
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

        snapshot_install_transaction "unknown" "gnome" "$TEST_USER"
        configure_gnome() { return 1; }
        DE="gnome"
        DISPLAY_SERVER="wayland"
        configure_desktop_integration
        eval "$GNOME_CONFIG_IMPLEMENTATION"
        if [[ "$INTEGRATION_RESULT" != "failed" ||
              "$(cat "$STATE_TEST_DIR/gnome-restored-sources")" != \
                "[('xkb', 'us'), ('xkb', 'us+intl')]" ]]; then
            exit 1
        fi
        rm -rf "$INSTALL_TRANSACTION_DIR"

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
        recover_incomplete_installation || exit 1
        if [[ "$(cat "$XKB_SYMBOLS_DIR/fr_custom")" != "original symbols" ||
              "$(cat "$EVDEV_XML")" != '<root>original rules</root>' ]]; then
            exit 1
        fi

        printf '<name>fr_custom</name>\n' > rules
        printf '<root><layoutList>\n</layoutList></root>\n' > "$EVDEV_XML"
        validate_and_inject_xml
        validate_and_inject_xml
        if [[ "$(grep -o '<name>fr_custom</name>' "$EVDEV_XML" | wc -l)" -ne 1 ]]; then
            exit 1
        fi

        : > "$XKB_SYMBOLS_DIR/fr_custom"
        : > "$INSTALLED_VERSION_FILE"
        if ! layout_installation_present; then
            exit 1
        fi
        rm -f "$XKB_SYMBOLS_DIR/fr_custom" "$INSTALLED_VERSION_FILE"
        if layout_installation_present; then
            exit 1
        fi
        mkdir -p "$(dirname "$DEBIAN_KEYBOARD_FILE")"
        : > "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom.absent"
        if ! layout_installation_present; then
            exit 1
        fi
        rm -f "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom.absent"
        mkdir -p "$INSTALL_STATE_DIR"
        : > "$INSTALL_STATE_DIR/system-x11-keyboard.conf"
        if ! layout_installation_present; then
            exit 1
        fi
        rm -rf "$INSTALL_STATE_DIR"
        if layout_installation_present; then
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
        echo "[PASS] Repeated backup calls preserve first-install state"
        echo "[PASS] Originally absent files retain their absent-state marker"
        echo "[PASS] Saved configuration restores original contents and absence"
        echo "[PASS] GNOME, KDE, and XFCE settings restore to their captured state"
        echo "[PASS] Incomplete install transactions restore original files"
        echo "[PASS] Repeated recovery is a safe no-op after successful recovery"
        echo "[PASS] Repeated XKB rule registration does not duplicate entries"
        echo "[PASS] Uninstall detects both installed state and already-removed state"
        echo "[PASS] Required command failures are returned to the installer"
        echo "[PASS] Optional desktop outcomes are reported distinctly"
        echo "[PASS] Failed optional integration restores partial desktop changes"
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
