# shellcheck shell=bash
# craft-rice — uninstall orchestration

quarantine_path() {
    local path="$1" rel dest stamp
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s would preserve modified file %s\n' "$C_DIM" "$C_RESET" "$path"
        return 0
    fi
    stamp="$(date '+%Y%m%d-%H%M%S')"
    rel="${path#/}"
    dest="$(cr_state_dir)/conflicts/uninstall-$stamp/$rel"
    mkdir -p "$(dirname "$dest")"
    mv -- "$path" "$dest"
    warn "Preserved modified file: $dest"
}

safe_to_remove_tree() {
    local path="$1"
    case "$path" in
        "$HOME"/*) return 0 ;;
        *) return 1 ;;
    esac
}

purge_packages() {
    [ "$PURGE_PACKAGES" = "1" ] || return 0
    [ -n "$PKG_REMOVE_CMD" ] || { warn "No package manager; remove packages manually."; return 0; }

    local logical resolved=() name
    for logical in niri kitty noctalia xwayland-satellite starship fastfetch; do
        name="$(pkg_name "$logical")"
        [ -n "$name" ] || continue
        feature_present "$logical" && resolved+=("$name")
    done
    if [ "$SHELL_NAME" = "fish" ]; then
        feature_present fish && resolved+=("$(pkg_name fish)")
    fi

    [ "${#resolved[@]}" -eq 0 ] && { info "Nothing to remove."; return 0; }

    warn "This will remove: ${resolved[*]}"
    warn "It will NOT remove shared dependencies (pipewire, gtk3, portals, ...)."
    if ! ask_yes_no "Really remove these packages?" "n"; then
        info "Keeping packages."
        return 0
    fi
    if ! ask_yes_no "Last chance — remove ${#resolved[@]} package(s)?" "n"; then
        info "Keeping packages."
        return 0
    fi

    run_shell "$PKG_REMOVE_CMD ${resolved[*]}" || warn "Some packages could not be removed."
}

do_uninstall() {
    local installed backup_id backup_dir shell kind path sha idx action src
    installed="$(cr_install_record)"

    if [ ! -f "$installed" ]; then
        die "craft-rice is not installed (no $installed). Nothing to undo."
    fi

    backup_id="$(awk -F'\t' '$1=="meta" && $2=="backup_id" {print $3; exit}' "$installed")"
    backup_dir="$(awk -F'\t' '$1=="meta" && $2=="backup_dir" {print $3; exit}' "$installed")"
    shell="$(awk -F'\t' '$1=="meta" && $2=="shell" {print $3; exit}' "$installed")"
    [ -n "$backup_dir" ] || backup_dir="$(cr_backup_root)/$backup_id"
    SHELL_NAME="${shell:-fish}"

    detect_arch
    detect_distro

    section "Uninstall plan"
    printf '  Remove craft-rice dotfiles and assets\n'
    printf '  Restore originals from: %s\n' "$backup_dir"
    [ "$PURGE_PACKAGES" = "1" ] && printf '  Then remove rice packages (asks again)\n'
    [ "$PURGE_STATE" = "1" ] && printf '  Then delete the entire state directory (including backups!)\n'
    printf '\n'

    if ! ask_yes_no "Uninstall craft-rice and restore your backups?" "y"; then
        info "Cancelled. Nothing was changed."
        return 0
    fi

    if [ "$PURGE_STATE" = "1" ]; then
        warn "This deletes every backup under $(cr_state_dir)."
        if ! ask_yes_no "Delete backups too?" "n"; then
            info "Keeping the state directory."
            PURGE_STATE=0
        fi
    fi

    if [ "$DRY_RUN" != "1" ]; then
        cr_lock
    fi

    CR_RESTORE_SKIP=()

    # ------------------------------------------------------------------
    # 1. Shell rc blocks
    # ------------------------------------------------------------------
    while IFS=$'\t' read -r kind path sha; do
        [ "$kind" = "block" ] || continue
        [ -n "$path" ] || continue

        if [ "$DRY_RUN" = "1" ]; then
            printf '%s[dry-run]%s would remove the craft-rice block from %s\n' "$C_DIM" "$C_RESET" "$path"
            CR_RESTORE_SKIP+=("$path")
            continue
        fi

        remove_shell_block "$path"
        CR_RESTORE_SKIP+=("$path")

        # Compare what is left with the backup copy.
        local entry idx2
        entry="$(awk -F'\t' -v t="$path" '$3==t {print $1"\t"$2; exit}' "$backup_dir/manifest.tsv" 2>/dev/null || true)"
        idx2="${entry%%$'\t'*}"
        action="${entry#*$'\t'}"

        if [ "$action" = "absent" ]; then
            # We created the rc file; remove it if only whitespace is left.
            if [ ! -s "$path" ] || ! grep -q '[^[:space:]]' "$path" 2>/dev/null; then
                run rm -f -- "$path"
            fi
        elif [ -n "$entry" ] && [ -n "$idx2" ]; then
            src="$backup_dir/files/$idx2"
            if [ -f "$src" ] && ! cmp -s "$path" "$src"; then
                warn "Kept your edits in $path (original also in $backup_dir)"
            fi
        fi
    done <"$installed"

    # ------------------------------------------------------------------
    # 2. Files, trees, directories, settings
    # ------------------------------------------------------------------
    while IFS=$'\t' read -r kind path sha; do
        case "$kind" in
            managed)
                [ -e "$path" ] || [ -L "$path" ] || continue
                if [ "$(sha256_of "$path")" = "$sha" ]; then
                    run rm -f -- "$path"
                else
                    quarantine_path "$path"
                fi
                ;;
            generated)
                [ -e "$path" ] || [ -L "$path" ] || continue
                run rm -f -- "$path"
                ;;
            symlink)
                [ -e "$path" ] || [ -L "$path" ] || continue
                if [ "$(readlink -- "$path" 2>/dev/null || true)" = "$sha" ]; then
                    run rm -f -- "$path"
                else
                    quarantine_path "$path"
                fi
                ;;
            tree)
                [ -e "$path" ] || [ -L "$path" ] || continue
                if safe_to_remove_tree "$path"; then
                    run rm -rf -- "$path"
                else
                    warn "Refusing to remove unexpected path: $path"
                fi
                ;;
            dir)
                # Pruned in a separate pass, after every file and tree above
                # has been removed.
                ;;
            gsetting)
                local schema key old
                schema="${path%% *}"
                key="${path#* }"
                old="$sha"
                if have gsettings && [ -n "$old" ]; then
                    run gsettings set "$schema" "$key" "$old" 2>/dev/null || true
                fi
                ;;
        esac
    done <"$installed"

    # Prune empty directories we created, deepest first. Anything with real
    # content is left alone.
    while IFS=$'\t' read -r kind path sha; do
        [ "$kind" = "dir" ] || continue
        [ -d "$path" ] || continue
        run find "$path" -depth -type d -empty -delete
    done <"$installed"

    # ------------------------------------------------------------------
    # 3. Restore the originals
    # ------------------------------------------------------------------
    if [ -d "$backup_dir" ]; then
        restore_backup "$backup_dir"
    else
        warn "Backup directory is missing: $backup_dir"
        warn "Your original dotfiles could not be restored automatically."
    fi

    # ------------------------------------------------------------------
    # 4. Optional package removal
    # ------------------------------------------------------------------
    purge_packages

    # ------------------------------------------------------------------
    # 5. State
    # ------------------------------------------------------------------
    if [ "$DRY_RUN" = "1" ]; then
        printf '\n%sDry run complete. Nothing was changed.%s\n\n' "$C_GREEN" "$C_RESET"
        return 0
    fi

    rm -f -- "$installed" "$(cr_state_dir)/repo.path" "$(journal_path)" 2>/dev/null || true
    if [ "$PURGE_STATE" = "1" ]; then
        rm -rf -- "$(cr_state_dir)"
        ok "Removed $(cr_state_dir)"
    else
        ok "Kept backups in $(cr_backup_root)"
    fi

    section "Uninstalled"
    cat <<EOF
  Your original dotfiles have been restored.
  Log out and back in (or restart Niri) to pick them up.

  Backups: $(cr_backup_root)
EOF
}
