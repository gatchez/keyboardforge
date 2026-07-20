#!/usr/bin/env bash
# File: modules/arch.sh

install_dependencies() {
    if ! command -v xmllint >/dev/null 2>&1; then
        log_info "Installing missing dependency: libxml2..."
        if [[ "$DRY_RUN" == "0" ]]; then
            pacman -Sy --noconfirm --needed libxml2 >> "$LOG_FILE" 2>&1
        fi
    fi
    if [[ ! -d "$XKB_SYMBOLS_DIR" ]]; then
        log_info "Installing missing dependency: xkeyboard-config..."
        if [[ "$DRY_RUN" == "0" ]]; then
            pacman -Sy --noconfirm --needed xkeyboard-config >> "$LOG_FILE" 2>&1
        fi
    fi
}

apply_arch_system_config() {
    log_info "Applying Arch Linux system configuration..."
    if [[ "$DRY_RUN" == "0" ]]; then
        # Arch is systemd-based, so localectl manages the X11 default layout
        # the same way it does on Fedora.
        safe_exec "Setting localectl x11-keymap" localectl set-x11-keymap fr_custom pc105 custom

        # Rebuilding the initramfs is NOT required for an X11-only XKB layout
        # change. This mirrors the safety step used on Debian/Fedora only in
        # case a console keymap hook depends on it, and is skipped entirely
        # if mkinitcpio isn't present (e.g. minimal/container installs).
        if command -v mkinitcpio >/dev/null 2>&1; then
            safe_exec "Rebuilding initramfs with mkinitcpio" mkinitcpio -P
        fi
    fi
    log_success "Arch Linux configurations applied."
}
