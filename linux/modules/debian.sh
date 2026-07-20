#!/usr/bin/env bash
# File: modules/debian.sh

install_dependencies() {
    if ! command -v xmllint >/dev/null 2>&1; then
        log_info "Installing missing dependency: libxml2-utils..."
        if [[ "$DRY_RUN" == "0" ]]; then
            apt-get update -y >> "$LOG_FILE" 2>&1
            apt-get install -y libxml2-utils >> "$LOG_FILE" 2>&1
        fi
    fi
}

apply_debian_system_config() {
    log_info "Applying Debian/Ubuntu system configuration..."
    local default_kbd="/etc/default/keyboard"
    check_writable "$default_kbd"

    if [[ -f "$default_kbd" ]]; then
        backup_file "$default_kbd"
    else
        log_warn "$default_kbd not found (common on minimal/container installs). It will be created."
        # Sentinel so uninstall.sh knows to remove the file entirely rather
        # than just reset its contents, restoring the original "absent" state.
        [[ "$DRY_RUN" == "0" ]] && : > "${default_kbd}.bak_fr_custom.absent"
    fi

    if [[ "$DRY_RUN" == "0" ]]; then
        [[ -f "$default_kbd" ]] || touch "$default_kbd"

        if grep -q "^XKBLAYOUT=" "$default_kbd"; then
            sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="fr_custom"/' "$default_kbd"
        else
            echo 'XKBLAYOUT="fr_custom"' >> "$default_kbd"
        fi

        if grep -q "^XKBVARIANT=" "$default_kbd"; then
            sed -i 's/^XKBVARIANT=.*/XKBVARIANT="custom"/' "$default_kbd"
        else
            echo 'XKBVARIANT="custom"' >> "$default_kbd"
        fi

        if command -v dpkg-reconfigure >/dev/null 2>&1; then
            safe_exec "Reconfiguring xkb-data" dpkg-reconfigure -f noninteractive xkb-data
        else
            log_warn "dpkg-reconfigure not found. Skipping xkb-data reconfiguration."
        fi
        if command -v update-initramfs >/dev/null 2>&1; then
            safe_exec "Updating initramfs" update-initramfs -u
        else
            log_warn "update-initramfs not found. Skipping initramfs update."
        fi
    fi
    log_success "Debian configurations applied."
}
