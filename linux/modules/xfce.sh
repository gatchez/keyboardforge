#!/usr/bin/env bash
# File: modules/xfce.sh

configure_xfce() {
    log_info "Configuring XFCE..."
    local export_dbus="export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$ACTUAL_USER")/bus;"

    if [[ "$DISPLAY_SERVER" == "x11" ]]; then
        safe_exec "Setting XFCE layout via xfconf-query" su - "$ACTUAL_USER" -c "$export_dbus xfconf-query -c keyboard-layout -p /Default/XkbLayout -s fr_custom --create -t string"
        safe_exec "Setting XFCE variant via xfconf-query" su - "$ACTUAL_USER" -c "$export_dbus xfconf-query -c keyboard-layout -p /Default/XkbVariant -s custom --create -t string"
        safe_exec "Applying setxkbmap" su - "$ACTUAL_USER" -c "setxkbmap fr_custom custom"
    else
        log_warn "XFCE Wayland detected. Custom layout must be applied via DE settings manually."
    fi
}
