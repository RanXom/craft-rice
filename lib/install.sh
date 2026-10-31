# shellcheck shell=bash
# craft-rice — install orchestration

RECORD=""
INSTALL_DONE=0
CR_RESTORE_SKIP=()

record_managed() {
    [ "$DRY_RUN" = "1" ] && return 0
    local path="$1"
    [ -e "$path" ] || [ -L "$path" ] || return 0
    printf 'managed\t%s\t%s\n' "$path" "$(sha256_of "$path")" >>"$RECORD"
}

record_generated() {
    [ "$DRY_RUN" = "1" ] && return 0
    printf 'generated\t%s\t-\n' "$1" >>"$RECORD"
}

record_tree() {
    [ "$DRY_RUN" = "1" ] && return 0
    printf 'tree\t%s\t-\n' "$1" >>"$RECORD"
}

record_dir() {
    [ "$DRY_RUN" = "1" ] && return 0
    printf 'dir\t%s\t-\n' "$1" >>"$RECORD"
}

record_symlink() {
    [ "$DRY_RUN" = "1" ] && return 0
    local path="$1" target
    target="$(readlink -- "$path" 2>/dev/null || true)"
    printf 'symlink\t%s\t%s\n' "$path" "$(tsv_escape "$target")" >>"$RECORD"
}

record_block() {
    [ "$DRY_RUN" = "1" ] && return 0
    printf 'block\t%s\t-\n' "$1" >>"$RECORD"
}

record_all_files_under() {
    [ "$DRY_RUN" = "1" ] && return 0
    local root="$1" f
    [ -d "$root" ] || return 0
    while IFS= read -r -d '' f; do
        record_managed "$f"
    done < <(find "$root" -type f -print0)
}

# ---------------------------------------------------------------------------
# Config modules
# ---------------------------------------------------------------------------

install_niri() {
    local dir f
    dir="$(cr_config_home)/niri"

    backup_path "$dir"
    run mkdir -p "$dir/animations"

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s render %s/config.kdl\n' "$C_DIM" "$C_RESET" "$dir"
        printf '%s[dry-run]%s render %s/outputs.kdl\n' "$C_DIM" "$C_RESET" "$dir"
        printf '%s[dry-run]%s copy animations and noctalia.kdl\n' "$C_DIM" "$C_RESET"
    else
        cr_render_niri "$dir/config.kdl"
        cp -a -- "$CR_ROOT/config/niri/animations/." "$dir/animations/"
        cr_generate_outputs "$dir/outputs.kdl"
        cp -- "$CR_ROOT/config/niri/noctalia.kdl" "$dir/noctalia.kdl"
        cr_render "$CR_ROOT/config/niri/extras.kdl" "$dir/extras.kdl"
    fi

    record_managed "$dir/config.kdl"
    record_managed "$dir/outputs.kdl"
    record_generated "$dir/noctalia.kdl"
    record_managed "$dir/extras.kdl"
    for f in "$dir"/animations/*.kdl; do
        [ -e "$f" ] && record_managed "$f"
    done
    record_dir "$dir"
    ok "Installed Niri config"
}

install_noctalia() {
    local dir
    dir="$(cr_config_home)/noctalia"

    backup_path "$dir"
    run mkdir -p "$dir/templates" "$dir/plugins"

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s render Noctalia config and plugins\n' "$C_DIM" "$C_RESET"
    else
        cp -- "$CR_ROOT/config/noctalia/config.toml" "$dir/config.toml"
        cp -- "$CR_ROOT/config/noctalia/plugins.json" "$dir/plugins.json"
        cp -- "$CR_ROOT/config/noctalia/templates.toml" "$dir/templates.toml"
        cp -- "$CR_ROOT/config/noctalia/templates/niri.kdl" "$dir/templates/niri.kdl"
        cp -a -- "$CR_ROOT/config/noctalia/plugins/." "$dir/plugins/"
        cr_render "$CR_ROOT/config/noctalia/settings.toml.tmpl" "$dir/settings.toml"
    fi

    record_all_files_under "$dir"
    record_dir "$dir"
    ok "Installed Noctalia config and $(find "$CR_ROOT/config/noctalia/plugins" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') plugins"
}

install_kitty() {
    local dir
    dir="$(cr_config_home)/kitty"

    backup_path "$dir"
    run mkdir -p "$dir/themes"

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s install Kitty config\n' "$C_DIM" "$C_RESET"
    else
        cp -- "$CR_ROOT/config/kitty/kitty.conf" "$dir/kitty.conf"
        cp -- "$CR_ROOT/config/kitty/themes/noctalia.conf" "$dir/themes/noctalia.conf"
    fi

    record_managed "$dir/kitty.conf"
    record_generated "$dir/themes/noctalia.conf"
    record_dir "$dir"
    ok "Installed Kitty config"
}

install_fastfetch() {
    local dir
    dir="$(cr_config_home)/fastfetch"

    backup_path "$dir"
    run mkdir -p "$dir"

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s install Fastfetch config\n' "$C_DIM" "$C_RESET"
    else
        cr_render "$CR_ROOT/config/fastfetch/config.jsonc.tmpl" "$dir/config.jsonc"
        cp -- "$CR_ROOT/config/fastfetch/logo.txt" "$dir/logo.txt"
    fi

    record_managed "$dir/config.jsonc"
    record_managed "$dir/logo.txt"
    record_dir "$dir"
    ok "Installed Fastfetch config"
}

install_starship() {
    local target
    target="$(cr_config_home)/starship.toml"

    backup_parent_if_symlink "$target"
    backup_path "$target"
    run mkdir -p "$(dirname "$target")"
    run cp -- "$CR_ROOT/config/starship/starship.toml" "$target"
    record_managed "$target"
    ok "Installed Starship config"
}

# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------

show_plan() {
    section "Install plan"
    cat <<EOF
  Niri          $(cr_config_home)/niri/
  Noctalia      $(cr_config_home)/noctalia/
  Kitty         $(cr_config_home)/kitty/
  Fastfetch     $(cr_config_home)/fastfetch/
  Starship      $(cr_config_home)/starship.toml
  Shell         $( [ "$SHELL_NAME" = fish ] && printf '%s' "$(cr_config_home)/fish/config.fish" || printf '%s' "$(shell_rc_file)" )
  Fonts         $(cr_data_home)/fonts/Monocraft.ttc
  Icons         $(cr_data_home)/icons/Pixel-Theme/
  Cursors       $(cr_data_home)/icons/JuxCursor/
  Wallpapers    $(cr_data_home)/backgrounds/craft-rice/
  Helpers       $(cr_home)/.local/bin/{craft-rice,craft-rice-oniri,craft-rice-polkit,oniri}
  Tool copy     $(cr_data_home)/craft-rice/
  Backups       $(cr_backup_root)/<timestamp>/
EOF
    if [ "$NIRI_HAS_BLUR" = "1" ]; then
        printf '\n  Niri blur: enabled\n'
    else
        printf '\n  Niri blur: disabled (Niri %s < 26.04)\n' "$NIRI_VERSION"
    fi
    printf '  Shell: %s\n\n' "$SHELL_NAME"
}

# ---------------------------------------------------------------------------
# Next steps
# ---------------------------------------------------------------------------

print_next_steps() {
    section "Done"
    cat <<EOF
  Start Niri at your login screen (choose "Niri").
  Already inside Niri? Reload the config:

      niri msg action reload-config

  Then check everything:

      craft-rice doctor
      craft-rice status
EOF

    if [ "$SHELL_NAME" != "fish" ]; then
        printf '\n  You kept %s. The Niri config was rendered for %s.\n' "$SHELL_NAME" "$SHELL_NAME"
    fi

    local login
    login="$(basename "${SHELL:-}")"
    if [ "$login" != "$SHELL_NAME" ] && [ "$SHELL_NAME" != "fish" ]; then
        printf '\n  To make %s your login shell:\n\n      chsh -s %s\n' "$SHELL_NAME" "$(command -v "$SHELL_NAME" 2>/dev/null || printf '%s' "$SHELL_NAME")"
    elif [ "$login" != "$SHELL_NAME" ]; then
        printf '\n  To make Fish your login shell:\n\n      chsh -s %s\n' "$(command -v fish 2>/dev/null || printf fish)"
    fi

    printf '\n  Undo everything:\n\n      craft-rice uninstall\n\n'
}

# ---------------------------------------------------------------------------
# Failure handling
# ---------------------------------------------------------------------------

install_abort() {
    if [ "$INSTALL_DONE" != "1" ] && [ "$BACKUP_ACTIVE" = "1" ]; then
        journal_rollback
        CR_RESTORE_SKIP=()
        restore_backup "$BACKUP_DIR" || true
        rm -f -- "$RECORD" 2>/dev/null || true
        rm -f -- "$(cr_install_record)" 2>/dev/null || true
        rm -rf -- "$BACKUP_DIR" 2>/dev/null || true
        rm -f -- "$(cr_backup_root)/current" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

do_install() {
    if [ ! -d "$CR_ROOT/config/niri" ] || [ ! -d "$CR_ROOT/assets" ]; then
        die "Install files not found in $CR_ROOT. Run ./install.sh from the craft-rice repository."
    fi

    if [ "$DRY_RUN" != "1" ]; then
        cr_lock
    fi

    preflight
    detect_shell

    scan_packages
    print_package_table
    install_missing_packages
    refresh_detection

    WALLPAPER_DIR="$(cr_data_home)/backgrounds/craft-rice"
    WALLPAPER_DEFAULT="$WALLPAPER_DIR/00-arch-black-4k.png"

    # Reinstalling over an existing install must not back up craft-rice's own
    # files as if they were the user's originals.
    REUSE_BACKUP=""
    if [ -f "$(cr_install_record)" ]; then
        local old_backup
        old_backup="$(awk -F'\t' '$1=="meta" && $2=="backup_dir" {print $3; exit}' "$(cr_install_record)")"
        if [ -z "$old_backup" ]; then
            old_backup="$(cr_backup_root)/$(awk -F'\t' '$1=="meta" && $2=="backup_id" {print $3; exit}' "$(cr_install_record)")"
        fi
        section "Already installed"
        warn "craft-rice is already installed on this account."
        if [ "$FORCE" != "1" ] && ! ask_yes_no "Reinstall over it? Your original dotfiles stay in the first backup." "n"; then
            info "Nothing changed. Run 'craft-rice uninstall' first if you want a clean slate."
            return 0
        fi
        if [ -d "$old_backup" ]; then
            REUSE_BACKUP="$old_backup"
            debug "will reuse originals from $old_backup"
        else
            warn "The previous backup is missing ($old_backup); originals cannot be carried over."
        fi
    fi

    show_plan
    if ! ask_yes_no "Proceed with the install?" "y"; then
        info "Cancelled. Nothing was changed."
        return 0
    fi

    mkdir -p "$(cr_state_dir)" "$(cr_backup_root)"
    RECORD="$(cr_state_dir)/installed.tsv.new"
    : >"$RECORD"
    printf 'meta\tbackup_id\t%s\n' "$(date '+%Y%m%d-%H%M%S')-$$" >>"$RECORD"
    printf 'meta\tversion\t%s\n' "$CR_VERSION" >>"$RECORD"
    printf 'meta\tshell\t%s\n' "$SHELL_NAME" >>"$RECORD"
    printf 'meta\tdistro\t%s\n' "$DISTRO_FAMILY" >>"$RECORD"

    # The real backup id is chosen by backup_begin; rewrite the header after.
    backup_begin
    if [ "$DRY_RUN" != "1" ]; then
        sed -i "s|^meta\tbackup_id\t.*|meta\tbackup_id\t$BACKUP_ID|" "$RECORD"
        printf 'meta\tbackup_dir\t%s\n' "$BACKUP_DIR" >>"$RECORD"
    fi
    journal_reset

    install_niri
    install_noctalia
    install_kitty
    install_fastfetch
    install_starship
    install_shell
    install_assets
    install_tool_copy
    apply_gtk_settings

    if [ -n "${REUSE_BACKUP:-}" ]; then
        merge_previous_backup "$REUSE_BACKUP"
    fi

    backup_finish

    if [ "$DRY_RUN" = "1" ]; then
        printf '\n%sDry run complete. Nothing was changed.%s\n\n' "$C_GREEN" "$C_RESET"
        INSTALL_DONE=1
        return 0
    fi

    # Finalise the install record.
    mkdir -p "$HOME/Pictures/Screenshots" 2>/dev/null || true
    record_dir "$HOME/Pictures/Screenshots"

    mv -f -- "$RECORD" "$(cr_install_record)"
    rm -f -- "$(journal_path)"

    INSTALL_DONE=1
    ok "craft-rice installed"
    print_next_steps
}
