#!/usr/bin/env bash
# File: modules/fedora.sh

install_dependencies() {
    if ! command -v xmllint >/dev/null 2>&1; then
        log_info "Installing missing dependency: libxml2..."
        if [[ "$DRY_RUN" == "0" ]]; then
            dnf install -y libxml2 >> "$LOG_FILE" 2>&1
        fi
    fi
}

apply_fedora_system_config() {
    log_info "Applying Fedora system configuration..."
    if [[ "$DRY_RUN" == "0" ]]; then
        snapshot_state_file \
            "/etc/X11/xorg.conf.d/00-keyboard.conf" \
            "system-x11-keyboard.conf" || {
                log_error "Could not save the original X11 keyboard configuration."
                return 1
            }
        # Only the X11 keymap is set here. The console (TTY) keymap uses a
        # different .map format and does not accept custom X11 layout names,
        # so it is intentionally left untouched.
        safe_exec "Setting localectl x11-keymap" localectl set-x11-keymap fr_custom pc105 custom
        safe_exec "Rebuilding initramfs with dracut" dracut -f
    fi
    log_success "Fedora configurations applied."
}
