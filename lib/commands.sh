# shellcheck shell=bash
# craft-rice — status, doctor, recover, outputs

cmd_version() {
    printf '%s %s\n' "$CR_NAME" "$CR_VERSION"
}

cmd_status() {
    local installed backup_id backup_dir shell
    installed="$(cr_install_record)"

    printf '%s %s\n' "$CR_NAME" "$CR_VERSION"

    if [ ! -f "$installed" ]; then
        printf 'Status: %snot installed%s\n' "$C_YELLOW" "$C_RESET"
        if [ -d "$(cr_backup_root)" ] && [ -n "$(ls -A "$(cr_backup_root)" 2>/dev/null)" ]; then
            printf 'Backups kept in: %s\n' "$(cr_backup_root)"
        fi
        return 0
    fi

    backup_id="$(awk -F'\t' '$1=="meta" && $2=="backup_id" {print $3; exit}' "$installed")"
    backup_dir="$(awk -F'\t' '$1=="meta" && $2=="backup_dir" {print $3; exit}' "$installed")"
    shell="$(awk -F'\t' '$1=="meta" && $2=="shell" {print $3; exit}' "$installed")"

    printf 'Status: %sinstalled%s\n' "$C_GREEN" "$C_RESET"
    printf 'Shell:  %s\n' "${shell:-unknown}"
    printf 'Backup: %s\n' "${backup_id:-unknown}"
    if [ -d "$backup_dir" ]; then
        printf '        %s (%s)\n' "$backup_dir" "$(du -sh "$backup_dir" 2>/dev/null | awk '{print $1}')"
    fi
    printf 'Repo:   %s\n' "$CR_ROOT"

    detect_niri
    detect_noctalia
    printf 'Niri:   %s' "$NIRI_VERSION"
    if [ "$NIRI_HAS_BLUR" = "1" ]; then
        printf ' (blur on)\n'
    else
        printf ' (blur off, needs >= 26.04)\n'
    fi
    printf 'Noctalia: %s\n' "$NOCTALIA_VERSION"

    printf '\nManaged files: %s\n' "$(awk -F'\t' '$1 ~ /^(managed|generated|symlink)$/ {n++} END {print n+0}' "$installed")"
    printf 'Config dir:    %s\n' "$(cr_config_home)"
    printf 'Assets dir:    %s\n' "$(cr_data_home)"
}

# ---------------------------------------------------------------------------
# Doctor
# ---------------------------------------------------------------------------

DOCTOR_FAILS=0

check_ok()   { printf '  %s✓%s %-28s %s\n' "$C_GREEN" "$C_RESET" "$1" "${2:-}"; }
check_warn() { printf '  %s!%s %-28s %s\n' "$C_YELLOW" "$C_RESET" "$1" "${2:-}"; }
check_fail() { printf '  %s✗%s %-28s %s\n' "$C_RED" "$C_RESET" "$1" "${2:-}"; DOCTOR_FAILS=$((DOCTOR_FAILS + 1)); }

cmd_doctor() {
    section "craft-rice doctor"
    DOCTOR_FAILS=0

    detect_arch
    detect_distro
    detect_niri
    detect_noctalia

    printf '  %-28s %s\n' "System" "$(distro_summary)"
    printf '  %-28s %s\n' "HOME" "$HOME"
    printf '  %-28s %s\n' "XDG_CONFIG_HOME" "$(cr_config_home)"
    printf '\n'

    # Core programs
    if have niri; then
        if [ "$NIRI_HAS_BLUR" = "1" ]; then
            check_ok "Niri" "$NIRI_VERSION"
        else
            check_warn "Niri" "$NIRI_VERSION (blur disabled)"
        fi
    else
        check_fail "Niri" "not installed"
    fi

    have noctalia && check_ok "Noctalia" "$NOCTALIA_VERSION" || check_fail "Noctalia" "not installed"
    have kitty && check_ok "Kitty" "$(kitty --version 2>/dev/null | head -n1)" || check_fail "Kitty" "not installed"
    have "$SHELL_NAME" && check_ok "Shell" "$SHELL_NAME" || check_fail "Shell" "$SHELL_NAME not installed"
    have starship && check_ok "Starship" "$(starship --version 2>/dev/null | head -n1)" || check_warn "Starship" "not installed (prompt will be plain)"
    have fastfetch && check_ok "Fastfetch" "installed" || check_warn "Fastfetch" "not installed (no greeting)"

    # Niri config
    local niri_config
    niri_config="$(cr_config_home)/niri/config.kdl"
    if [ -f "$niri_config" ]; then
        check_ok "Niri config" "$niri_config"
        if have niri; then
            if niri validate -c "$niri_config" >/dev/null 2>&1; then
                check_ok "Niri config syntax" "valid"
            else
                check_fail "Niri config syntax" "niri validate failed"
            fi
        fi
    else
        check_fail "Niri config" "missing"
    fi

    [ -f "$(cr_config_home)/noctalia/settings.toml" ] \
        && check_ok "Noctalia config" "present" \
        || check_fail "Noctalia config" "missing"

    [ -f "$(cr_config_home)/kitty/kitty.conf" ] \
        && check_ok "Kitty config" "present" \
        || check_fail "Kitty config" "missing"

    # Fonts
    local font_list=""
    if have fc-list; then
        font_list="$(fc-list 2>/dev/null || true)"
    fi
    case "$font_list" in
        *[Mm]onocraft*)
            check_ok "Monocraft font" "registered" ;;
        *)
            if [ -f "$(cr_data_home)/fonts/Monocraft.ttc" ]; then
                check_warn "Monocraft font" "file present but not in fontconfig"
            else
                check_fail "Monocraft font" "missing"
            fi ;;
    esac

    # Icons and cursors
    [ -d "$(cr_data_home)/icons/Pixel-Theme" ] \
        && check_ok "Pixel-Theme icons" "present" \
        || check_fail "Pixel-Theme icons" "missing"
    [ -d "$(cr_data_home)/icons/JuxCursor" ] \
        && check_ok "JuxCursor cursors" "present" \
        || check_fail "JuxCursor cursors" "missing"

    # Shell integration
    case "$SHELL_NAME" in
        fish)
            [ -f "$(cr_config_home)/fish/config.fish" ] \
                && check_ok "Fish config" "present" \
                || check_fail "Fish config" "missing" ;;
        zsh|bash)
            if shell_block_present "$(shell_rc_file)"; then
                check_ok "$SHELL_NAME integration" "block present in $(shell_rc_file)"
            else
                check_warn "$SHELL_NAME integration" "block missing in $(shell_rc_file)"
            fi ;;
    esac

    # Session helpers
    [ -x "$(cr_home)/.local/bin/craft-rice-oniri" ] \
        && check_ok "oniri wrapper" "present" \
        || check_warn "oniri wrapper" "missing"
    [ -x "$(cr_home)/.local/bin/craft-rice-polkit" ] \
        && check_ok "polkit wrapper" "present" \
        || check_warn "polkit wrapper" "missing"

    # Portals / session essentials
    have wl-copy && check_ok "wl-clipboard" "present" || check_warn "wl-clipboard" "missing"
    have playerctl && check_ok "playerctl" "present" || check_warn "playerctl" "missing"

    printf '\n'
    if [ "$DOCTOR_FAILS" -eq 0 ]; then
        ok "No blocking problems found."
        return 0
    fi
    err "$DOCTOR_FAILS blocking problem(s)."
    return 1
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

cmd_outputs() {
    local dst
    dst="$(cr_config_home)/niri/outputs.kdl"
    mkdir -p "$(dirname "$dst")"

    if [ -f "$dst" ]; then
        cp -p -- "$dst" "$dst.bak.$(date '+%Y%m%d-%H%M%S')"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s would write %s\n' "$C_DIM" "$C_RESET" "$dst"
        return 0
    fi

    cr_generate_outputs "$dst"
    ok "Wrote $dst"
    printf 'Reload Niri with: niri msg action reload-config\n'
}

# ---------------------------------------------------------------------------
# Recover
# ---------------------------------------------------------------------------

cmd_recover() {
    local jp backup_dir latest record
    jp="$(journal_path)"
    record="$(cr_install_record)"

    if [ -f "$jp" ] && [ -s "$jp" ]; then
        section "Interrupted install detected"
        if [ "$DRY_RUN" = "1" ]; then
            printf '%s[dry-run]%s would roll back the unfinished install\n' "$C_DIM" "$C_RESET"
            return 0
        fi

        backup_dir="$(readlink -f "$(cr_backup_root)/current" 2>/dev/null || true)"
        if [ -n "$backup_dir" ] && [ -d "$backup_dir" ]; then
            warn "Rolling back the unfinished install and restoring backups."
            if rollback_from_backup "$backup_dir"; then
                [ -n "${CR_LAST_CONFLICT_DIR:-}" ] && rm -rf -- "$CR_LAST_CONFLICT_DIR" 2>/dev/null
                rm -rf -- "$backup_dir" 2>/dev/null || true
                rm -f -- "$(cr_backup_root)/current" 2>/dev/null || true
            fi
        else
            warn "No backup for the interrupted install; removing its record only."
        fi

        rm -f -- "$jp" "$record" "$(cr_state_dir)/installed.tsv.new" 2>/dev/null || true
        ok "Recovery complete."
        return 0
    fi

    section "Available backups"
    if [ ! -d "$(cr_backup_root)" ] || [ -z "$(ls -A "$(cr_backup_root)" 2>/dev/null)" ]; then
        info "No backups found."
        return 0
    fi

    find "$(cr_backup_root)" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort

    latest="$(find "$(cr_backup_root)" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | tail -n1)"
    [ -n "$latest" ] || return 0

    if ! ask_yes_no "Restore the newest backup ($latest)?" "n"; then
        info "Nothing restored."
        return 0
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s would restore %s\n' "$C_DIM" "$C_RESET" "$latest"
        return 0
    fi

    CR_RESTORE_SKIP=()
    restore_backup "$(cr_backup_root)/$latest"
    ok "Restored $latest"
}

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

cmd_help() {
    cat <<EOF
${C_BOLD}craft-rice ${CR_VERSION}${C_RESET} — Niri + Noctalia rice, portable.

${C_BOLD}USAGE${C_RESET}
  ./install.sh [command] [flags]

${C_BOLD}COMMANDS${C_RESET}
  install        Install the rice (default)
  uninstall      Remove the rice and restore every backup
  status         Show what is installed and where
  doctor         Check the session for problems
  recover        Roll back an interrupted install, or restore a backup
  outputs        Snapshot the current monitor layout into outputs.kdl
  version        Print the version
  help           This text

${C_BOLD}FLAGS${C_RESET}
  --dry-run           Show what would happen, change nothing
  --yes, -y           Answer yes to every prompt
  --no-packages       Never call the package manager
  --minimal           Skip optional integrations (reserved)
  --force             Continue on NixOS / unsupported setups
  --purge-packages    Also remove rice packages (asks twice)
  --purge-state       Also delete backups on uninstall (asks twice)
  --verbose, -v       Extra detail

${C_BOLD}ENVIRONMENT${C_RESET}
  CRAFT_RICE_SHELL=fish|zsh|bash   Skip the shell question
  XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_STATE_HOME   Respected

${C_BOLD}EXAMPLES${C_RESET}
  ./install.sh --dry-run
  ./install.sh install --no-packages
  craft-rice doctor
  craft-rice uninstall
EOF
}
