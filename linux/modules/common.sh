#!/usr/bin/env bash
# File: modules/common.sh

VERSION=$(cat "$(dirname "${BASH_SOURCE[0]}")/../VERSION" 2>/dev/null || echo "1.2.0")
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/install.log"
XKB_SYMBOLS_DIR="/usr/share/X11/xkb/symbols"
XKB_RULES_DIR="/usr/share/X11/xkb/rules"
EVDEV_XML="${XKB_RULES_DIR}/evdev.xml"
INSTALLED_VERSION_FILE="${XKB_SYMBOLS_DIR}/fr_custom.version"
INSTALL_STATE_DIR="/var/lib/keyboardforge/fr_custom"
INSTALL_TRANSACTION_DIR="${INSTALL_STATE_DIR}/transaction"
DEBIAN_KEYBOARD_FILE="/etc/default/keyboard"
SYSTEM_X11_KEYBOARD_FILE="/etc/X11/xorg.conf.d/00-keyboard.conf"
LOCK_DIR="/tmp/fr_custom_installer.lock"
INTEGRATION_RESULT="pending"
INTEGRATION_DETAIL=""
DRY_RUN="${DRY_RUN:-0}"

# --- LOGGING ENGINE (timestamped file, clean console) ---
log_msg() {
    local type="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    # Print clean version to terminal
    echo -e "$msg"
    if [[ "$DRY_RUN" != "1" ]]; then
        mkdir -p "$LOG_DIR" || return 1
        echo "[$timestamp] $msg" >> "$LOG_FILE" || return 1
    fi
}
log_info()    { log_msg "INFO"    " [i] $1"; }
log_success() { log_msg "SUCCESS" "[✔] $1"; }
log_warn()    { log_msg "WARN"    "[!] WARNING: $1"; }
log_error()   { log_msg "ERROR"   "[X] ERROR: $1"; }

# --- CONCURRENCY PROTECTION ---
acquire_lock() {
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] Would acquire installer lock: $LOCK_DIR"
        return 0
    fi

    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log_error "Another instance is running. (Lock: $LOCK_DIR)"
        exit 1
    fi
    # Ensure lock is released on exit
    trap 'rm -rf "$LOCK_DIR"' EXIT
}

# --- COMMAND EXECUTION ---
safe_exec() {
    local desc="$1"
    shift
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] Would execute: $*"
        return 0
    fi
    log_info "Running: $desc"
    if "$@" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        log_error "Failed: $desc. Check $LOG_FILE for details."
        return 1
    fi
}

configure_desktop_integration() {
    local configure_status=0

    if [[ "$DRY_RUN" == "1" ]]; then
        INTEGRATION_RESULT="simulated"
        INTEGRATION_DETAIL="Desktop settings were not changed during the dry run."
        return 0
    fi

    if [[ "$DE" == "fallback" ]]; then
        INTEGRATION_RESULT="manual"
        INTEGRATION_DETAIL="No supported desktop environment was detected."
        return 0
    fi

    if [[ "$DE" == "xfce" && "$DISPLAY_SERVER" != "x11" ]]; then
        INTEGRATION_RESULT="manual"
        INTEGRATION_DETAIL="XFCE automatic configuration is supported only on X11."
        return 0
    fi

    case "$DE" in
        gnome) configure_gnome || configure_status=$? ;;
        kde) configure_kde || configure_status=$? ;;
        xfce) configure_xfce || configure_status=$? ;;
        *)
            INTEGRATION_RESULT="manual"
            INTEGRATION_DETAIL="The detected desktop environment is not supported."
            return 0
            ;;
    esac

    if [[ "$configure_status" == "0" ]]; then
        INTEGRATION_RESULT="configured"
        INTEGRATION_DETAIL="Desktop keyboard settings were configured."
    else
        INTEGRATION_RESULT="failed"
        INTEGRATION_DETAIL="Automatic desktop keyboard configuration failed."
        log_warn "$INTEGRATION_DETAIL The system-wide layout installation can still be used; see the troubleshooting instructions."
        if [[ -f "${INSTALL_TRANSACTION_DIR}/desktop" ]] &&
            ! restore_desktop_state "$INSTALL_TRANSACTION_DIR" 1; then
            log_error "Could not restore desktop settings after the optional integration failure."
            return 1
        fi
    fi
}

report_installation_result() {
    case "$INTEGRATION_RESULT" in
        configured)
            log_success "Core layout installation and desktop integration completed. Reboot recommended."
            ;;
        simulated)
            log_success "Dry run completed; no system installation changes were made."
            ;;
        manual)
            log_warn "Core layout installation completed, but desktop integration needs manual configuration. $INTEGRATION_DETAIL See steps.txt."
            ;;
        failed)
            log_warn "Core layout installation completed, but automatic desktop integration failed. $INTEGRATION_DETAIL Check the log and configure the layout manually if needed."
            ;;
        *)
            log_error "Installation completed without a recorded desktop integration result."
            return 1
            ;;
    esac
}

check_writable() {
    local target="$1"
    if [[ -e "$target" && ! -w "$target" ]]; then
        log_error "File system locked or permission denied: $target"
        exit 1
    elif [[ ! -e "$target" && ! -w "$(dirname "$target")" ]]; then
        log_error "Directory not writable: $(dirname "$target")"
        exit 1
    fi
}

backup_file() {
    local file=$1
    local backup_file="${file}.bak_fr_custom"
    local absent_marker="${backup_file}.absent"

    if [[ -f "$file" ]]; then
        if [[ -e "$backup_file" || -e "$absent_marker" ]]; then
            log_info "Preserving original backup state for $file."
            return 0
        fi
        if [[ "$DRY_RUN" == "1" ]]; then
            log_info "[DRY-RUN] Would back up: $file -> $backup_file"
            return 0
        fi
        cp -a "$file" "$backup_file" || return 1
        log_success "Backup created: $backup_file"
    fi
}

snapshot_state_file_to() {
    local source_file="$1"
    local state_dir="$2"
    local state_name="$3"
    local snapshot="${state_dir}/${state_name}"

    mkdir -p "$state_dir" || return 1
    chmod 700 "$state_dir" || return 1
    if [[ -e "$source_file" ]]; then
        cp -a "$source_file" "$snapshot" || return 1
    else
        : > "${snapshot}.absent" || return 1
    fi
}

restore_state_file_from() {
    local state_dir="$1"
    local state_name="$2"
    local destination="$3"
    local snapshot="${state_dir}/${state_name}"

    if [[ -f "$snapshot" ]]; then
        mkdir -p "$(dirname "$destination")" || return 1
        cp -a "$snapshot" "$destination"
    elif [[ -e "${snapshot}.absent" ]]; then
        rm -f "$destination"
    else
        return 2
    fi
}

snapshot_install_transaction() {
    local distro="$1"
    local desktop="$2"
    local user="$3"
    local targets=(
        "${XKB_SYMBOLS_DIR}/fr_custom:layout"
        "${EVDEV_XML}:evdev"
        "${INSTALLED_VERSION_FILE}:version-marker"
        "${XKB_SYMBOLS_DIR}/fr_custom.bak_fr_custom:layout-backup"
        "${EVDEV_XML}.bak_fr_custom:evdev-backup"
    )
    local target
    local name
    local source_file

    rm -rf "$INSTALL_TRANSACTION_DIR" || return 1
    mkdir -p "$INSTALL_TRANSACTION_DIR" || return 1
    chmod 700 "$INSTALL_TRANSACTION_DIR" || return 1
    chmod 700 "$INSTALL_STATE_DIR" || return 1

    case "$distro" in
        debian)
            targets+=(
                "${DEBIAN_KEYBOARD_FILE}:system-keyboard"
                "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom:system-keyboard-backup"
                "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom.absent:system-keyboard-absent-marker"
            )
            ;;
        fedora|arch)
            targets+=(
                "${SYSTEM_X11_KEYBOARD_FILE}:system-x11-keyboard"
            )
            ;;
    esac

    for target in "${targets[@]}"; do
        source_file="${target%:*}"
        name="${target##*:}"
        snapshot_state_file_to "$source_file" "$INSTALL_TRANSACTION_DIR" "$name" || return 1
    done

    if [[ "$desktop" != "fallback" ]]; then
        snapshot_desktop_state "$user" "$desktop" "$INSTALL_TRANSACTION_DIR" || return 1
    fi
    : > "${INSTALL_TRANSACTION_DIR}/active" || return 1
}

rollback_install_transaction() {
    local result=0

    [[ -f "${INSTALL_TRANSACTION_DIR}/active" ]] || return 0
    log_warn "Rolling back the incomplete installation..."

    restore_state_file_from "$INSTALL_TRANSACTION_DIR" "layout" \
        "${XKB_SYMBOLS_DIR}/fr_custom" || result=1
    restore_state_file_from "$INSTALL_TRANSACTION_DIR" "evdev" \
        "$EVDEV_XML" || result=1
    restore_state_file_from "$INSTALL_TRANSACTION_DIR" "version-marker" \
        "$INSTALLED_VERSION_FILE" || result=1
    restore_state_file_from "$INSTALL_TRANSACTION_DIR" "layout-backup" \
        "${XKB_SYMBOLS_DIR}/fr_custom.bak_fr_custom" || result=1
    restore_state_file_from "$INSTALL_TRANSACTION_DIR" "evdev-backup" \
        "${EVDEV_XML}.bak_fr_custom" || result=1

    if [[ -f "${INSTALL_TRANSACTION_DIR}/system-keyboard" || \
          -f "${INSTALL_TRANSACTION_DIR}/system-keyboard.absent" ]]; then
        restore_state_file_from "$INSTALL_TRANSACTION_DIR" "system-keyboard" \
            "$DEBIAN_KEYBOARD_FILE" || result=1
        restore_state_file_from "$INSTALL_TRANSACTION_DIR" "system-keyboard-backup" \
            "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom" || result=1
        restore_state_file_from "$INSTALL_TRANSACTION_DIR" "system-keyboard-absent-marker" \
            "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom.absent" || result=1
    fi
    if [[ -f "${INSTALL_TRANSACTION_DIR}/system-x11-keyboard" || \
          -f "${INSTALL_TRANSACTION_DIR}/system-x11-keyboard.absent" ]]; then
        restore_state_file_from "$INSTALL_TRANSACTION_DIR" "system-x11-keyboard" \
            "$SYSTEM_X11_KEYBOARD_FILE" || result=1
    fi

    if [[ -f "${INSTALL_TRANSACTION_DIR}/desktop" ]]; then
        restore_desktop_state "$INSTALL_TRANSACTION_DIR" 1 || result=1
    fi

    if [[ -f "${INSTALL_TRANSACTION_DIR}/system-keyboard" || \
          -f "${INSTALL_TRANSACTION_DIR}/system-keyboard.absent" ]]; then
        if command -v dpkg-reconfigure >/dev/null 2>&1; then
            safe_exec "Reconfiguring xkb-data after rollback" \
                dpkg-reconfigure -f noninteractive xkb-data || result=1
        fi
        if command -v update-initramfs >/dev/null 2>&1; then
            safe_exec "Updating initramfs after rollback" update-initramfs -u || result=1
        fi
    elif [[ -f "${INSTALL_TRANSACTION_DIR}/system-x11-keyboard" || \
            -f "${INSTALL_TRANSACTION_DIR}/system-x11-keyboard.absent" ]]; then
        if command -v dracut >/dev/null 2>&1; then
            safe_exec "Rebuilding initramfs after rollback" dracut -f || result=1
        elif command -v mkinitcpio >/dev/null 2>&1; then
            safe_exec "Rebuilding initramfs after rollback" mkinitcpio -P || result=1
        fi
    fi

    if [[ "$result" == "0" ]]; then
        rm -f "${INSTALL_TRANSACTION_DIR}/active" || return 1
        if ! rm -rf "$INSTALL_TRANSACTION_DIR"; then
            log_warn "Rollback completed, but transaction cleanup failed at ${INSTALL_TRANSACTION_DIR}."
        fi
        clear_xkb_cache
        log_success "Incomplete installation changes were rolled back."
    else
        log_error "Rollback was incomplete. Recovery snapshots remain at ${INSTALL_TRANSACTION_DIR}."
    fi
    return "$result"
}

recover_incomplete_installation() {
    if [[ -f "${INSTALL_TRANSACTION_DIR}/active" ]]; then
        log_warn "An incomplete installation transaction was found."
        rollback_install_transaction
    fi
}

layout_installation_present() {
    [[ -e "${XKB_SYMBOLS_DIR}/fr_custom" ||
       -e "$INSTALLED_VERSION_FILE" ||
       -e "${EVDEV_XML}.bak_fr_custom" ||
       -e "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom" ||
       -e "${DEBIAN_KEYBOARD_FILE}.bak_fr_custom.absent" ||
       ( -d "$INSTALL_STATE_DIR" &&
         -n "$(find "$INSTALL_STATE_DIR" -mindepth 1 -print -quit 2>/dev/null)" ) ]]
}

check_layout_conflicts() {
    local layout_name="$1"
    local symbols_file="$2"
    local rules_file="$3"
    local installed_marker="$4"
    local conflict_description=""

    if [[ -e "$symbols_file" ]]; then
        conflict_description="XKB symbols file '$symbols_file'"
    fi

    if [[ -f "$rules_file" ]] && grep -Fq "<name>${layout_name}</name>" "$rules_file"; then
        if [[ -n "$conflict_description" ]]; then
            conflict_description+=" and "
        fi
        conflict_description+="rules entry '$layout_name' in '$rules_file'"
    fi

    if [[ -z "$conflict_description" ]]; then
        return 0
    fi

    if [[ -f "$installed_marker" ]]; then
        log_info "Existing KeyboardForge installation detected; allowing managed reinstall."
        return 0
    fi

    log_error "Cannot install '$layout_name': existing ${conflict_description} is not owned by a marked KeyboardForge installation."
    log_info "No system files were changed. Resolve the conflict or remove the existing layout before retrying."
    return 1
}

snapshot_state_file() {
    local source_file="$1"
    local state_name="$2"
    local snapshot="${INSTALL_STATE_DIR}/${state_name}"

    if [[ -e "$snapshot" || -e "${snapshot}.absent" ]]; then
        return 0
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] Would record original state of $source_file."
        return 0
    fi

    snapshot_state_file_to "$source_file" "$INSTALL_STATE_DIR" "$state_name"
}

restore_state_file() {
    local snapshot="$1"
    local destination="$2"

    if [[ -f "$snapshot" ]]; then
        mkdir -p "$(dirname "$destination")" || return 1
        cp -a "$snapshot" "$destination" || return 1
        rm -f "$snapshot"
        return
    fi

    if [[ -e "${snapshot}.absent" ]]; then
        rm -f "$destination" "${snapshot}.absent"
        return
    fi

    return 2
}

user_home_directory() {
    local passwd_entry
    passwd_entry=$(getent passwd "$1") || return 1
    printf '%s\n' "${passwd_entry#*:*:*:*:*:}"
    return 0
}

snapshot_desktop_state() {
    local user="$1"
    local desktop="$2"
    local state_dir="${3:-$INSTALL_STATE_DIR}"
    local user_home
    local uid
    local dbus_address
    local original_sources
    local quoted_sources
    local snapshot="${state_dir}/gnome-input-sources"

    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] Would record original $desktop settings for $user."
        return 0
    fi

    if [[ -f "${state_dir}/desktop" ]]; then
        log_info "Preserving existing desktop settings snapshot."
        return 0
    fi

    user_home=$(user_home_directory "$user") || {
        log_warn "Cannot determine home directory for $user; desktop settings will not be changed."
        return 1
    }
    uid=$(id -u "$user") || return 1
    dbus_address="unix:path=/run/user/${uid}/bus"
    mkdir -p "$state_dir" || return 1
    chmod 700 "$state_dir" || return 1

    case "$desktop" in
        gnome)
            if original_sources=$(su - "$user" -c \
                "DBUS_SESSION_BUS_ADDRESS='$dbus_address' gsettings get org.gnome.desktop.input-sources sources" \
                2>>"$LOG_FILE"); then
                printf '%s\n' "$original_sources" > "$snapshot" || return 1
            else
                : > "${snapshot}.unavailable" || return 1
                log_warn "Could not capture GNOME input sources; GNOME input-source changes will be skipped."
            fi
            ;;
        kde)
            snapshot_state_file_to "${user_home}/.config/kxkbrc" "$state_dir" "kde-kxkbrc" || {
                rm -f "${state_dir}/kde-kxkbrc" \
                    "${state_dir}/kde-kxkbrc.absent"
                return 1
            }
            ;;
        xfce)
            snapshot_state_file_to \
                "${user_home}/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml" \
                "$state_dir" "xfce-keyboard-layout.xml" || {
                    rm -f "${state_dir}/xfce-keyboard-layout.xml" \
                        "${state_dir}/xfce-keyboard-layout.xml.absent"
                    return 1
                }
            ;;
        *)
            return 0
            ;;
    esac

    printf '%s\n' "$user" > "${state_dir}/user" || return 1
    printf '%s\n' "$user_home" > "${state_dir}/home" || return 1
    printf '%s\n' "$desktop" > "${state_dir}/desktop" || return 1
}

restore_desktop_state() {
    local state_dir="${1:-$INSTALL_STATE_DIR}"
    local preserve_snapshot="${2:-0}"
    local user_file="${state_dir}/user"
    local home_file="${state_dir}/home"
    local desktop_file="${state_dir}/desktop"
    local user
    local user_home
    local desktop
    local uid
    local dbus_address
    local original_sources
    local quoted_sources

    if [[ ! -f "$user_file" || ! -f "$home_file" || ! -f "$desktop_file" ]]; then
        log_warn "No complete saved desktop-state snapshot found; desktop settings were not restored."
        return 1
    fi

    user=$(<"$user_file")
    user_home=$(<"$home_file")
    desktop=$(<"$desktop_file")
    uid=$(id -u "$user") || return 1
    dbus_address="unix:path=/run/user/${uid}/bus"

    case "$desktop" in
        gnome)
            if [[ -f "${state_dir}/gnome-input-sources" ]]; then
                original_sources=$(<"${state_dir}/gnome-input-sources")
                printf -v quoted_sources '%q' "$original_sources"
                if ! su - "$user" -c \
                    "DBUS_SESSION_BUS_ADDRESS='$dbus_address' gsettings set org.gnome.desktop.input-sources sources ${quoted_sources}" \
                    >> "$LOG_FILE" 2>&1; then
                    log_warn "Could not restore GNOME input sources for $user."
                    return 1
                fi
                if [[ "$preserve_snapshot" != "1" ]]; then
                    rm -f "${state_dir}/gnome-input-sources" || return 1
                fi
            elif [[ -f "${state_dir}/gnome-input-sources.unavailable" ]]; then
                log_warn "GNOME settings were not changed because their original value could not be captured."
                if [[ "$preserve_snapshot" != "1" ]]; then
                    rm -f "${state_dir}/gnome-input-sources.unavailable" || return 1
                fi
            fi
            ;;
        kde)
            if [[ "$preserve_snapshot" == "1" ]]; then
                restore_state_file_from "$state_dir" "kde-kxkbrc" \
                    "${user_home}/.config/kxkbrc" || return 1
            else
                restore_state_file "${state_dir}/kde-kxkbrc" \
                    "${user_home}/.config/kxkbrc" || return 1
            fi
            if command -v qdbus >/dev/null 2>&1; then
                su - "$user" -c \
                    "DBUS_SESSION_BUS_ADDRESS='$dbus_address' qdbus org.kde.keyboard /Layouts reconfigure" \
                    >> "$LOG_FILE" 2>&1 || log_warn "Could not refresh the KDE keyboard daemon."
            fi
            ;;
        xfce)
            if [[ "$preserve_snapshot" == "1" ]]; then
                restore_state_file_from "$state_dir" "xfce-keyboard-layout.xml" \
                    "${user_home}/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml" \
                    || return 1
            else
                restore_state_file "${state_dir}/xfce-keyboard-layout.xml" \
                    "${user_home}/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml" \
                    || return 1
            fi
            ;;
        *)
            log_warn "Unknown saved desktop '$desktop'; desktop settings were not restored."
            return 1
            ;;
    esac

    if [[ "$preserve_snapshot" != "1" ]]; then
        rm -f "$user_file" "$home_file" "$desktop_file" || return 1
    fi
    log_success "Restored saved $desktop settings for $user."
}

detect_actual_user() {
    ACTUAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
}

detect_display_server() {
    if [[ -n "$WAYLAND_DISPLAY" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        DISPLAY_SERVER="wayland"
    else
        DISPLAY_SERVER="x11"
    fi
}

detect_desktop_environment() {
    local de="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"

    # If sudo stripped the desktop variables, fall back to checking the
    # actual user's running processes.
    if [[ -z "$de" || "$de" == "tty" ]]; then
        if pgrep -u "$ACTUAL_USER" -x "gnome-shell" >/dev/null 2>&1; then
            de="gnome"
        elif pgrep -u "$ACTUAL_USER" -x "plasmashell" >/dev/null 2>&1; then
            de="kde"
        elif pgrep -u "$ACTUAL_USER" -x "xfce4-session" >/dev/null 2>&1; then
            de="xfce"
        fi
    fi

    de=$(echo "$de" | tr '[:upper:]' '[:lower:]')
    if [[ "$de" == *"gnome"* ]]; then
        DE="gnome"
    elif [[ "$de" == *"kde"* || "$de" == *"plasma"* ]]; then
        DE="kde"
    elif [[ "$de" == *"xfce"* ]]; then
        DE="xfce"
    else
        DE="fallback"
    fi
}

validate_and_inject_xml() {
    check_writable "$EVDEV_XML"

    if grep -q "<name>fr_custom</name>" "$EVDEV_XML"; then
        log_warn "fr_custom already exists in $EVDEV_XML. Skipping injection."
        return 0
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] Would validate and inject rules into $EVDEV_XML"
        return 0
    fi

    if command -v xmllint >/dev/null 2>&1; then
        log_info "xmllint found. Validating XML format before injection..."
        if ! xmllint --noout "$EVDEV_XML" >> "$LOG_FILE" 2>&1; then
            log_error "Existing $EVDEV_XML is malformed. Aborting injection."
            exit 1
        fi
    fi

    sed -i -e '/<layoutList>/r rules' "$EVDEV_XML" || {
        log_error "Failed to inject layout rules into $EVDEV_XML."
        return 1
    }

    if command -v xmllint >/dev/null 2>&1; then
        if ! xmllint --noout "$EVDEV_XML" >> "$LOG_FILE" 2>&1; then
            log_error "XML injection corrupted the file! Rolling back..."
            mv "${EVDEV_XML}.bak_fr_custom" "$EVDEV_XML"
            exit 1
        fi
    fi

    log_success "Injected and validated layout rules in $EVDEV_XML"
}

clear_xkb_cache() {
    log_info "Clearing XKB cache..."
    if [[ "$DRY_RUN" == "0" ]]; then
        rm -rf /var/lib/xkb/* >> "$LOG_FILE" 2>&1 || true
    fi
}

check_version_upgrade() {
    if [[ -f "$INSTALLED_VERSION_FILE" ]]; then
        local CURRENT_VER
        CURRENT_VER=$(cat "$INSTALLED_VERSION_FILE")
        if [[ "$CURRENT_VER" == "$VERSION" ]]; then
            log_info "Version $VERSION is already installed. Reinstalling."
        else
            log_info "Upgrading from v$CURRENT_VER to v$VERSION..."
        fi
    elif grep -q "<name>fr_custom</name>" "$EVDEV_XML" 2>/dev/null; then
        log_info "Legacy layout version detected. Upgrading to v$VERSION..."
    fi
}
