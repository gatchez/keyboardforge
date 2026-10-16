#!/usr/bin/env bash
# File: modules/kde.sh

configure_kde() {
    log_info "Configuring KDE for user $ACTUAL_USER..."
    local export_dbus="export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$ACTUAL_USER")/bus;"

    local config_tool
    if command -v kwriteconfig6 >/dev/null 2>&1; then
        config_tool="kwriteconfig6"
    elif command -v kwriteconfig5 >/dev/null 2>&1; then
        config_tool="kwriteconfig5"
    else
        log_warn "Neither kwriteconfig5 nor kwriteconfig6 is available."
        return 1
    fi

    safe_exec "Setting KDE layout" su - "$ACTUAL_USER" -c "$export_dbus $config_tool --file kxkbrc --group Layout --key LayoutList fr_custom" || return 1
    safe_exec "Setting KDE variant" su - "$ACTUAL_USER" -c "$export_dbus $config_tool --file kxkbrc --group Layout --key VariantList custom" || return 1

    log_info "Attempting to refresh KDE keyboard daemon..."
    if command -v qdbus >/dev/null 2>&1 &&
        ! su - "$ACTUAL_USER" -c "$export_dbus qdbus org.kde.keyboard /Layouts reconfigure" >> "$LOG_FILE" 2>&1; then
        log_warn "KDE settings were saved, but the keyboard daemon could not be refreshed. Log out and back in to apply them."
    fi
}
