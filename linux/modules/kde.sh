#!/usr/bin/env bash
# File: modules/kde.sh

configure_kde() {
    log_info "Configuring KDE for user $ACTUAL_USER..."
    local export_dbus="export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$ACTUAL_USER")/bus;"

    # Attempt kwriteconfig5 (Plasma 5) and kwriteconfig6 (Plasma 6). One of
    # the two is silently allowed to fail depending on the installed version.
    su - "$ACTUAL_USER" -c "$export_dbus kwriteconfig5 --file kxkbrc --group Layout --key LayoutList fr_custom" >/dev/null 2>&1
    safe_exec "Setting KDE layout (kwriteconfig6)" su - "$ACTUAL_USER" -c "$export_dbus kwriteconfig6 --file kxkbrc --group Layout --key LayoutList fr_custom"

    su - "$ACTUAL_USER" -c "$export_dbus kwriteconfig5 --file kxkbrc --group Layout --key VariantList custom" >/dev/null 2>&1
    safe_exec "Setting KDE variant (kwriteconfig6)" su - "$ACTUAL_USER" -c "$export_dbus kwriteconfig6 --file kxkbrc --group Layout --key VariantList custom"

    log_info "Attempting to refresh KDE keyboard daemon..."
    # Silent fail if qdbus/org.kde.keyboard is missing -- common on minimal
    # installs (Fedora, Arch) or on newer Plasma 6 systems.
    su - "$ACTUAL_USER" -c "$export_dbus qdbus org.kde.keyboard /Layouts reconfigure" >/dev/null 2>&1 || true
}
