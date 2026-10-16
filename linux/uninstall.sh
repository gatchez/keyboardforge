#!/usr/bin/env bash
# File: uninstall.sh

cd "$(dirname "$0")" || exit 1
source modules/common.sh

DRY_RUN=0

set -E
trap 'log_error "Unexpected failure at line $LINENO in command: $BASH_COMMAND"' ERR

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo ./uninstall.sh)."
    exit 1
fi

acquire_lock

log_info "Starting uninstallation..."

if [[ -f "${INSTALL_STATE_DIR}/desktop" ]]; then
    restore_desktop_state || log_warn "Review desktop settings for manual restoration."
elif [[ -d "$INSTALL_STATE_DIR" ]]; then
    log_warn "No complete desktop-state snapshot found; review desktop settings manually."
fi

# 1. Restore evdev.xml
if [[ -f "${EVDEV_XML}.bak_fr_custom" ]]; then
    mv "${EVDEV_XML}.bak_fr_custom" "$EVDEV_XML"
    log_success "Restored $EVDEV_XML from backup."
else
    log_warn "No backup found for evdev.xml. You may need to manually remove the fr_custom <layout> entry."
fi

# 2. Remove symbols file
if [[ -f "${XKB_SYMBOLS_DIR}/fr_custom" ]]; then
    rm -f "${XKB_SYMBOLS_DIR}/fr_custom"
    rm -f "${XKB_SYMBOLS_DIR}/fr_custom.bak_fr_custom"
    log_success "Removed layout file from ${XKB_SYMBOLS_DIR}"
fi
rm -f "$INSTALLED_VERSION_FILE"

# 3. Restore OS-level configs
if [[ -f /etc/debian_version ]]; then
    restore_state_file "/etc/default/keyboard.bak_fr_custom" \
        "/etc/default/keyboard" \
        || log_warn "Could not restore /etc/default/keyboard; review it manually."
    if command -v dpkg-reconfigure >/dev/null 2>&1; then
        safe_exec "Reconfiguring xkb-data" dpkg-reconfigure -f noninteractive xkb-data
    fi
    if command -v update-initramfs >/dev/null 2>&1; then
        safe_exec "Updating initramfs" update-initramfs -u
    fi
    log_success "Restored Debian system configurations."
elif [[ -f /etc/fedora-release ]]; then
    restore_state_file "${INSTALL_STATE_DIR}/system-x11-keyboard.conf" \
        "/etc/X11/xorg.conf.d/00-keyboard.conf" \
        || log_warn "Could not restore Fedora's X11 keyboard configuration; review it manually."
    if command -v dracut >/dev/null 2>&1; then
        safe_exec "Rebuilding initramfs with dracut" dracut -f
    fi
    log_success "Restored Fedora system keyboard configuration."
elif [[ -f /etc/arch-release ]]; then
    restore_state_file "${INSTALL_STATE_DIR}/system-x11-keyboard.conf" \
        "/etc/X11/xorg.conf.d/00-keyboard.conf" \
        || log_warn "Could not restore Arch's X11 keyboard configuration; review it manually."
    if command -v mkinitcpio >/dev/null 2>&1; then
        safe_exec "Rebuilding initramfs with mkinitcpio" mkinitcpio -P
    fi
    log_success "Restored Arch system keyboard configuration."
fi

clear_xkb_cache
if [[ -d "$INSTALL_STATE_DIR" ]]; then
    rmdir "$INSTALL_STATE_DIR" 2>/dev/null || log_warn "Saved installer state remains at $INSTALL_STATE_DIR."
    rmdir "$(dirname "$INSTALL_STATE_DIR")" 2>/dev/null || true
fi

log_success "Uninstallation complete. Please reboot."
