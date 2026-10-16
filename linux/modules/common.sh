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
LOCK_DIR="/tmp/fr_custom_installer.lock"

mkdir -p "$LOG_DIR"

# --- LOGGING ENGINE (timestamped file, clean console) ---
log_msg() {
    local type="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    # Print clean version to terminal
    echo -e "$msg"
    # Print timestamped version to log file
    echo "[$timestamp] $msg" >> "$LOG_FILE"
}
log_info()    { log_msg "INFO"    " [i] $1"; }
log_success() { log_msg "SUCCESS" "[✔] $1"; }
log_warn()    { log_msg "WARN"    "[!] WARNING: $1"; }
log_error()   { log_msg "ERROR"   "[X] ERROR: $1"; }

# --- CONCURRENCY PROTECTION ---
acquire_lock() {
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log_error "Another instance is running. (Lock: $LOCK_DIR)"
        exit 1
    fi
    # Ensure lock is released on exit
    trap 'rm -rf "$LOCK_DIR"' EXIT
}

# --- ROBUST EXECUTION (never trips the global ERR trap on handled failures) ---
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
        log_warn "Failed: $desc. Check $LOG_FILE for details."
        return 0
    fi
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
        cp "$file" "$backup_file"
        log_success "Backup created: $backup_file"
    fi
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

    mkdir -p "$INSTALL_STATE_DIR" || return 1
    if [[ -e "$source_file" ]]; then
        cp -a "$source_file" "$snapshot" || return 1
    else
        : > "${snapshot}.absent" || return 1
    fi
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
    local user_home
    local uid
    local dbus_address
    local original_sources
    local quoted_sources
    local snapshot="${INSTALL_STATE_DIR}/gnome-input-sources"

    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] Would record original $desktop settings for $user."
        return 0
    fi

    if [[ -f "${INSTALL_STATE_DIR}/desktop" ]]; then
        log_info "Preserving existing desktop settings snapshot."
        return 0
    fi

    user_home=$(user_home_directory "$user") || {
        log_warn "Cannot determine home directory for $user; desktop settings will not be changed."
        return 1
    }
    uid=$(id -u "$user") || return 1
    dbus_address="unix:path=/run/user/${uid}/bus"
    mkdir -p "$INSTALL_STATE_DIR" || return 1
    chmod 700 "$INSTALL_STATE_DIR" || return 1

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
            snapshot_state_file "${user_home}/.config/kxkbrc" "kde-kxkbrc" || {
                rm -f "${INSTALL_STATE_DIR}/kde-kxkbrc" \
                    "${INSTALL_STATE_DIR}/kde-kxkbrc.absent"
                return 1
            }
            ;;
        xfce)
            snapshot_state_file \
                "${user_home}/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml" \
                "xfce-keyboard-layout.xml" || {
                    rm -f "${INSTALL_STATE_DIR}/xfce-keyboard-layout.xml" \
                        "${INSTALL_STATE_DIR}/xfce-keyboard-layout.xml.absent"
                    return 1
                }
            ;;
        *)
            return 0
            ;;
    esac

    printf '%s\n' "$user" > "${INSTALL_STATE_DIR}/user" || return 1
    printf '%s\n' "$user_home" > "${INSTALL_STATE_DIR}/home" || return 1
    printf '%s\n' "$desktop" > "${INSTALL_STATE_DIR}/desktop" || return 1
}

restore_desktop_state() {
    local user_file="${INSTALL_STATE_DIR}/user"
    local home_file="${INSTALL_STATE_DIR}/home"
    local desktop_file="${INSTALL_STATE_DIR}/desktop"
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
            if [[ -f "${INSTALL_STATE_DIR}/gnome-input-sources" ]]; then
                original_sources=$(<"${INSTALL_STATE_DIR}/gnome-input-sources")
                printf -v quoted_sources '%q' "$original_sources"
                if ! su - "$user" -c \
                    "DBUS_SESSION_BUS_ADDRESS='$dbus_address' gsettings set org.gnome.desktop.input-sources sources ${quoted_sources}" \
                    >> "$LOG_FILE" 2>&1; then
                    log_warn "Could not restore GNOME input sources for $user."
                    return 1
                fi
                rm -f "${INSTALL_STATE_DIR}/gnome-input-sources" || return 1
            elif [[ -f "${INSTALL_STATE_DIR}/gnome-input-sources.unavailable" ]]; then
                log_warn "GNOME settings were not changed because their original value could not be captured."
                rm -f "${INSTALL_STATE_DIR}/gnome-input-sources.unavailable" || return 1
            fi
            ;;
        kde)
            restore_state_file "${INSTALL_STATE_DIR}/kde-kxkbrc" \
                "${user_home}/.config/kxkbrc" || return 1
            if command -v qdbus >/dev/null 2>&1; then
                su - "$user" -c \
                    "DBUS_SESSION_BUS_ADDRESS='$dbus_address' qdbus org.kde.keyboard /Layouts reconfigure" \
                    >> "$LOG_FILE" 2>&1 || log_warn "Could not refresh the KDE keyboard daemon."
            fi
            ;;
        xfce)
            restore_state_file "${INSTALL_STATE_DIR}/xfce-keyboard-layout.xml" \
                "${user_home}/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml" \
                || return 1
            ;;
        *)
            log_warn "Unknown saved desktop '$desktop'; desktop settings were not restored."
            return 1
            ;;
    esac

    rm -f "$user_file" "$home_file" "$desktop_file" || return 1
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

    sed -i -e '/<layoutList>/r rules' "$EVDEV_XML"

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
