#!/usr/bin/env bash
# File: modules/common.sh

VERSION=$(cat "$(dirname "${BASH_SOURCE[0]}")/../VERSION" 2>/dev/null || echo "1.2.0")
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/install.log"
XKB_SYMBOLS_DIR="/usr/share/X11/xkb/symbols"
XKB_RULES_DIR="/usr/share/X11/xkb/rules"
EVDEV_XML="${XKB_RULES_DIR}/evdev.xml"
INSTALLED_VERSION_FILE="${XKB_SYMBOLS_DIR}/fr_custom.version"
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
    if [[ -f "$file" ]]; then
        if [[ "$DRY_RUN" == "1" ]]; then
            log_info "[DRY-RUN] Would back up: $file -> ${file}.bak_fr_custom"
            return 0
        fi
        cp "$file" "${file}.bak_fr_custom"
        log_success "Backup created: ${file}.bak_fr_custom"
    fi
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
