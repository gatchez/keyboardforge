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
    if [[ -f /etc/default/keyboard.bak_fr_custom ]]; then
        mv /etc/default/keyboard.bak_fr_custom /etc/default/keyboard
    elif [[ -f /etc/default/keyboard.bak_fr_custom.absent ]]; then
        # The file did not exist before install; restore that exact state.
        rm -f /etc/default/keyboard /etc/default/keyboard.bak_fr_custom.absent
    elif [[ -f /etc/default/keyboard ]]; then
        sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="us"/' /etc/default/keyboard
        sed -i 's/^XKBVARIANT=.*/XKBVARIANT=""/' /etc/default/keyboard
    fi
    if command -v dpkg-reconfigure >/dev/null 2>&1; then
        safe_exec "Reconfiguring xkb-data" dpkg-reconfigure -f noninteractive xkb-data
    fi
    if command -v update-initramfs >/dev/null 2>&1; then
        safe_exec "Updating initramfs" update-initramfs -u
    fi
    log_success "Restored Debian system configurations."
elif [[ -f /etc/fedora-release ]]; then
    if command -v localectl >/dev/null 2>&1; then
        safe_exec "Resetting localectl x11-keymap" localectl set-x11-keymap us
        safe_exec "Resetting localectl keymap" localectl set-keymap us
    fi
    if command -v dracut >/dev/null 2>&1; then
        safe_exec "Rebuilding initramfs with dracut" dracut -f
    fi
    log_success "Reset Fedora system layout to default (us)."
elif [[ -f /etc/arch-release ]]; then
    if command -v localectl >/dev/null 2>&1; then
        safe_exec "Resetting localectl x11-keymap" localectl set-x11-keymap us
    fi
    if command -v mkinitcpio >/dev/null 2>&1; then
        safe_exec "Rebuilding initramfs with mkinitcpio" mkinitcpio -P
    fi
    log_success "Reset Arch Linux system layout to default (us)."
fi

clear_xkb_cache

log_success "Uninstallation complete. Please reboot."
