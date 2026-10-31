# shellcheck shell=bash
# craft-rice — fonts, icons, cursors, wallpapers and helper binaries

# ---------------------------------------------------------------------------
# Pixel-Theme
# ---------------------------------------------------------------------------

prepare_pixel_theme() {
    local dir="$1"

    # Upstream inherits from breeze and gnome; gnome is not guaranteed.
    sed -i \
        -e 's/^Inherits=breeze,gnome$/Inherits=breeze-dark,Adwaita,hicolor/' \
        -e 's/^FollowsColorScheme=true$/FollowsColorScheme=false/' \
        "$dir/index.theme"

    # Four symlinks point at the author's machine (/home/paul/...).
    local link target
    while IFS=: read -r link target; do
        [ -n "$link" ] || continue
        if [ -e "$dir/$(dirname "$link")/$target" ]; then
            ln -sfn "$target" "$dir/$link"
        else
            warn "Pixel-Theme: missing $target for $link"
        fi
    done <<'EOF'
mimetypes/scalable/gnome-mime-application-pdf.svg:pdf.svg
mimetypes/scalable/application-pdf.svg:pdf.svg
mimetypes/scalable/application-epub+zip.svg:ebook.svg
places/scalable/other-desktop.svg:desktop.svg
EOF

    # Bridge names that apps ask for but the pack ships under another name.
    local alias_name target_name target_file target_dir
    while IFS=: read -r alias_name target_name; do
        [ -n "$alias_name" ] || continue
        target_file="$(find "$dir" -name "$target_name.svg" -print -quit 2>/dev/null)"
        if [ -z "$target_file" ]; then
            warn "Pixel-Theme: no $target_name.svg for alias $alias_name"
            continue
        fi
        target_dir="$(dirname "$target_file")"
        [ -e "$target_dir/$alias_name.svg" ] && continue
        ln -s "$target_name.svg" "$target_dir/$alias_name.svg"
    done <<'EOF'
text-plain:txt
text-x-generic:txt
directory:folder
folder-x-generic:folder
folder-desktop:user-desktop
folder-shared:folder-publicshare
kitty:utilities-terminal
org.gnome.Nautilus:org.gnome.files
nvim:code-editor
application-x-executable:terminal
preferences-system-network:preferences-system
office-chart-line-symbolic:calc
knetattach:network
EOF

    if have gtk-update-icon-cache; then
        gtk-update-icon-cache -f -t "$dir" >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

write_helper() {
    local path="$1"
    shift
    backup_path "$path"
    run mkdir -p "$(dirname "$path")"
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s write helper %s\n' "$C_DIM" "$C_RESET" "$path"
        return 0
    fi
    cat >"$path"
    chmod 755 "$path"
    journal_add file "$path"
    record_managed "$path"
}

install_helper_scripts() {
    local bin
    bin="$(cr_home)/.local/bin"
    backup_note_created_dir "$bin"
    run mkdir -p "$bin"

    write_helper "$bin/craft-rice-oniri" <<'EOF'
#!/usr/bin/env bash
# Launch oniri if it is installed; otherwise do nothing.
# Keeps Niri's startup quiet on machines without the optional binary.
set -u
if [ -x "$HOME/.local/bin/oniri" ]; then
    exec "$HOME/.local/bin/oniri" "$@"
fi
if command -v oniri >/dev/null 2>&1; then
    exec oniri "$@"
fi
exit 0
EOF

    write_helper "$bin/craft-rice-polkit" <<'EOF'
#!/usr/bin/env bash
# Start the first available polkit authentication agent.
set -u
for candidate in lxqt-policykit-agent polkit-gnome-authentication-agent-1 hyprpolkitagent; do
    if command -v "$candidate" >/dev/null 2>&1; then
        exec "$candidate"
    fi
done
for candidate in \
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
    /usr/libexec/polkit-gnome-authentication-agent-1 \
    /usr/libexec/hyprpolkitagent; do
    if [ -x "$candidate" ]; then
        exec "$candidate"
    fi
done
exit 0
EOF

    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
        backup_path "$bin/oniri"
        run cp -- "$CR_ROOT/assets/bin/oniri-x86_64" "$bin/oniri"
        run chmod 755 "$bin/oniri"
        journal_add file "$bin/oniri"
        record_managed "$bin/oniri"
    else
        info "Skipping bundled oniri (x86_64 only; you are on $ARCH)"
    fi
    record_dir "$bin"
}

# ---------------------------------------------------------------------------
# Main asset install
# ---------------------------------------------------------------------------

install_assets() {
    local data icons fonts cursors wallpapers
    data="$(cr_data_home)"
    icons="$data/icons"
    fonts="$data/fonts"
    cursors="$data/icons/JuxCursor"
    wallpapers="$data/backgrounds/craft-rice"

    # Fonts
    backup_path "$fonts/Monocraft.ttc"
    backup_note_created_dir "$fonts"
    run mkdir -p "$fonts"
    run cp -- "$CR_ROOT/assets/fonts/Monocraft-nerd-fonts-patched.ttc" "$fonts/Monocraft.ttc"
    journal_add file "$fonts/Monocraft.ttc"
    record_managed "$fonts/Monocraft.ttc"
    record_dir "$fonts"
    ok "Installed Monocraft"

    # Icons
    backup_path "$icons/Pixel-Theme"
    backup_note_created_dir "$icons"
    run mkdir -p "$icons"
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s extract Pixel-Theme to %s\n' "$C_DIM" "$C_RESET" "$icons/Pixel-Theme"
    else
        local tmp
        tmp="$(mktemp -d "${TMPDIR:-/tmp}/craft-rice-icons.XXXXXX")"
        tar -xzf "$CR_ROOT/assets/icons/Pixel-Theme_0.6.2.tar" -C "$tmp" 2>/dev/null
        rm -rf -- "$tmp/__MACOSX"
        find "$tmp/Pixel-Theme" -name '.DS_Store' -delete 2>/dev/null || true
        prepare_pixel_theme "$tmp/Pixel-Theme"
        mv -- "$tmp/Pixel-Theme" "$icons/Pixel-Theme"
        rmdir -- "$tmp" 2>/dev/null || rm -rf -- "$tmp"
        journal_add tree "$icons/Pixel-Theme"
    fi
    record_tree "$icons/Pixel-Theme"
    record_dir "$icons"
    ok "Installed Pixel-Theme icons"

    # Cursors
    backup_path "$cursors"
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s extract JuxCursor to %s\n' "$C_DIM" "$C_RESET" "$cursors"
    else
        run mkdir -p "$icons"
        tar -xzf "$CR_ROOT/assets/cursors/JuxCursor.tar.gz" -C "$icons" 2>/dev/null
        journal_add tree "$cursors"
    fi
    record_tree "$cursors"
    ok "Installed JuxCursor"

    # Wallpapers
    backup_path "$wallpapers"
    backup_note_created_dir "$(dirname "$wallpapers")"
    run mkdir -p "$wallpapers"
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s copy wallpapers to %s\n' "$C_DIM" "$C_RESET" "$wallpapers"
    else
        cp -a -- "$CR_ROOT/assets/wallpapers/." "$wallpapers/"
        journal_add tree "$wallpapers"
    fi
    record_tree "$wallpapers"
    record_dir "$(dirname "$wallpapers")"
    ok "Installed $(find "$CR_ROOT/assets/wallpapers" -maxdepth 1 -type f | wc -l | tr -d ' ') wallpapers"

    install_helper_scripts

    # Refresh caches.
    if [ "$DRY_RUN" != "1" ]; then
        have fc-cache && fc-cache -f >/dev/null 2>&1 || true
        if have gtk-update-icon-cache; then
            gtk-update-icon-cache -f -t "$icons/Pixel-Theme" >/dev/null 2>&1 || true
            gtk-update-icon-cache -f -t "$cursors" >/dev/null 2>&1 || true
        fi
    fi
}

# ---------------------------------------------------------------------------
# Installed copy of the CLI (so `craft-rice uninstall` works later)
# ---------------------------------------------------------------------------

install_tool_copy() {
    local data tool bin
    data="$(cr_data_home)"
    tool="$data/craft-rice"
    bin="$(cr_home)/.local/bin"

    backup_path "$tool"
    backup_path "$bin/craft-rice"
    backup_note_created_dir "$bin"

    run mkdir -p "$tool/bin" "$tool/lib" "$bin"
    run cp -- "$CR_ROOT/bin/craft-rice" "$tool/bin/craft-rice"
    run cp -- "$CR_ROOT"/lib/*.sh "$tool/lib/"
    run cp -- "$CR_ROOT/lib/outputs.py" "$tool/lib/"
    run chmod 755 "$tool/bin/craft-rice"
    run ln -sfn "$tool/bin/craft-rice" "$bin/craft-rice"

    journal_add tree "$tool"
    journal_add file "$bin/craft-rice"

    record_tree "$tool"
    record_symlink "$bin/craft-rice"
    record_dir "$bin"

    if [ "$DRY_RUN" != "1" ]; then
        mkdir -p "$(cr_state_dir)"
        printf '%s\n' "$CR_ROOT" >"$(cr_state_dir)/repo.path"
    fi
    ok "Installed craft-rice command"
}

# ---------------------------------------------------------------------------
# GTK / desktop settings
# ---------------------------------------------------------------------------

gset_record() {
    local schema="$1" key="$2" value="$3" old
    have gsettings || return 0
    old="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    if [ -n "$old" ]; then
        printf 'gsetting\t%s %s\t%s\n' "$schema" "$key" "$(tsv_escape "$old")" >>"${RECORD:-$(cr_install_record)}"
    fi
    run gsettings set "$schema" "$key" "$value" 2>/dev/null || true
}

apply_gtk_settings() {
    have gsettings || { debug "gsettings not found; skipping GTK settings"; return 0; }
    [ "$DRY_RUN" = "1" ] && { info "[dry-run] would set GTK icon/cursor/font settings"; return 0; }

    gset_record org.gnome.desktop.interface icon-theme "Pixel-Theme"
    gset_record org.gnome.desktop.interface cursor-theme "JuxCursor"
    gset_record org.gnome.desktop.interface cursor-size 24
    gset_record org.gnome.desktop.interface font-name "Monocraft 10"
    gset_record org.gnome.desktop.interface monospace-font-name "Monocraft 10"
    ok "Applied GTK icon, cursor and font settings"
}

# revert_gsettings_from RECORD — put the previous values back after a failed install.
revert_gsettings_from() {
    local record="$1"
    [ -n "$record" ] && [ -f "$record" ] || return 0
    have gsettings || return 0

    local kind path old schema key
    while IFS=$'\t' read -r kind path old; do
        [ "$kind" = "gsetting" ] || continue
        [ -n "$old" ] || continue
        schema="${path%% *}"
        key="${path#* }"
        gsettings set "$schema" "$key" "$old" 2>/dev/null || true
    done <"$record"
}
