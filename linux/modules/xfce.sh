#!/usr/bin/env bash
# File: modules/xfce.sh

configure_xfce() {
    log_info "Configuring XFCE..."
    local export_dbus="export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$ACTUAL_USER")/bus;"

    if [[ "$DISPLAY_SERVER" == "x11" ]]; then
        safe_exec "Setting XFCE layout via xfconf-query" su - "$ACTUAL_USER" -c "$export_dbus xfconf-query -c keyboard-layout -p /Default/XkbLayout -s $LAYOUT_NAME --create -t string" || return 1
        safe_exec "Setting XFCE variant via xfconf-query" su - "$ACTUAL_USER" -c "$export_dbus xfconf-query -c keyboard-layout -p /Default/XkbVariant -s $LAYOUT_VARIANT --create -t string" || return 1
        safe_exec "Applying setxkbmap" su - "$ACTUAL_USER" -c "setxkbmap $LAYOUT_NAME $LAYOUT_VARIANT" || return 1
    else
        log_warn "XFCE Wayland detected. Custom layout must be applied via DE settings manually."
        return 2
    fi
}
