#!/usr/bin/env bash
# File: install.sh

# --- EARLY STRICT VALIDATION ---
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Please execute this script directly: ./install.sh"
    exit 1
fi

cd "$(dirname "$0")" || exit 1

for req_file in "modules/common.sh" "fr_custom" "rules" "VERSION"; do
    if [[ ! -f "$req_file" ]]; then
        echo "ERROR: Missing required file: $req_file. Are you in the correct directory?"
        exit 1
    fi
done

# --- INIT ---
source modules/common.sh
source modules/gnome.sh
source modules/kde.sh
source modules/xfce.sh

# --- GLOBAL ERROR TRAP (set once logging is available) ---
set -E
trap 'log_error "Unexpected failure at line $LINENO in command: $BASH_COMMAND"' ERR

DRY_RUN=0
SILENT=0
LAYOUT_NAME="fr_custom"
LAYOUT_VARIANT="custom"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --layout-name)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "ERROR: --layout-name requires a value." >&2
                exit 1
            fi
            LAYOUT_NAME="$2"
            shift 2
            ;;
        --variant)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "ERROR: --variant requires a value." >&2
                exit 1
            fi
            LAYOUT_VARIANT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --yes|-y)
            SILENT=1
            shift
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ "$LAYOUT_NAME" != "fr_custom" || "$LAYOUT_VARIANT" != "custom" ]]; then
    echo "ERROR: This installer currently supports only fr_custom/custom." >&2
    exit 1
fi

# Initialize a fresh log with a session header
echo "--- SESSION START: $(date) ---" > "$LOG_FILE"
echo -e "============================================================\n FR_CUSTOM Installer v$VERSION\n============================================================"

if [[ $EUID -ne 0 ]]; then
    log_error "This script requires root privileges. Run: sudo ./install.sh"
    exit 1
fi

acquire_lock

# --- USER PROMPT ---
if [[ "$SILENT" == "0" && "$DRY_RUN" == "0" ]]; then
    read -p "Proceed with system installation? [y/N]: " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        log_info "Installation aborted by user."
        exit 0
    fi
fi

log_info "Installing core layout files..."

# --- OS DETECTION & DEPENDENCIES ---
if [[ -f /etc/debian_version ]]; then
    OS="debian"
    source modules/debian.sh
elif [[ -f /etc/fedora-release ]]; then
    OS="fedora"
    source modules/fedora.sh
elif [[ -f /etc/arch-release ]]; then
    OS="arch"
    source modules/arch.sh
else
    log_error "Unsupported OS. Supported: Debian/Ubuntu, Fedora, Arch Linux."
    log_info "See steps.txt for manual installation."
    exit 1
fi

log_success "Detected OS type: $OS"

if ! check_layout_conflicts \
    "$LAYOUT_NAME" \
    "${XKB_SYMBOLS_DIR}/${LAYOUT_NAME}" \
    "$EVDEV_XML" \
    "$INSTALLED_VERSION_FILE"; then
    exit 1
fi

install_dependencies

# --- CORE FILES INSTALLATION ---
check_writable "$XKB_SYMBOLS_DIR"
check_version_upgrade

backup_file "${XKB_SYMBOLS_DIR}/fr_custom"
safe_exec "Copying layout file" cp "fr_custom" "${XKB_SYMBOLS_DIR}/fr_custom"
safe_exec "Setting permissions on layout" chmod 644 "${XKB_SYMBOLS_DIR}/fr_custom"
[[ "$DRY_RUN" == "0" ]] && echo "$VERSION" > "$INSTALLED_VERSION_FILE"

backup_file "$EVDEV_XML"
validate_and_inject_xml

# --- OS-LEVEL SYSTEM CONFIGURATION ---
if [[ "$OS" == "debian" ]]; then apply_debian_system_config; fi
if [[ "$OS" == "fedora" ]]; then apply_fedora_system_config; fi
if [[ "$OS" == "arch" ]];   then apply_arch_system_config;   fi

# --- DESKTOP ENVIRONMENT CONFIGURATION ---
detect_actual_user
detect_display_server
detect_desktop_environment

log_success "Detected User: $ACTUAL_USER | Display: $DISPLAY_SERVER | DE: $DE"

if [[ "$DE" != "fallback" ]] && ! snapshot_desktop_state "$ACTUAL_USER" "$DE"; then
    log_warn "Could not capture desktop settings; automatic desktop configuration is skipped."
    DE="fallback"
fi

if [[ "$DISPLAY_SERVER" == "wayland" ]]; then
    log_warn "Wayland detected. Skipping setxkbmap (X11-only utility)."
fi

if [[ "$DRY_RUN" == "0" ]]; then
    case "$DE" in
        gnome) configure_gnome ;;
        kde)   configure_kde ;;
        xfce)  configure_xfce ;;
        *) log_warn "Fallback mode: Please configure the layout manually in your DE (see steps.txt)." ;;
    esac
fi

clear_xkb_cache

log_success "Installation Complete. See steps.txt for Wayland notes. Reboot recommended."
