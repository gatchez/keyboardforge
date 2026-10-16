#!/usr/bin/env bash
# File: modules/gnome.sh

configure_gnome() {
    log_info "Configuring GNOME for user $ACTUAL_USER..."
    if [[ ! -f "${INSTALL_STATE_DIR}/gnome-input-sources" ]]; then
        log_warn "Skipping GNOME input-source changes because the original value was not captured."
        return 0
    fi
    local export_dbus="export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$ACTUAL_USER")/bus;"
    # GNOME represents layout+variant as a single ('xkb','fr_custom+custom') source
    safe_exec "Setting GNOME layout via gsettings" su - "$ACTUAL_USER" -c "$export_dbus gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'fr_custom+custom')]\""
}
