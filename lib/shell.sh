# shellcheck shell=bash
# craft-rice — shell integration
#
# fish gets a whole config file. zsh and bash get a small marked block in their
# rc file that sources a helper under ~/.config/craft-rice/.

CR_BLOCK_START="# >>> craft-rice >>>"
CR_BLOCK_END="# <<< craft-rice <<<"

shell_rc_file() {
    case "$SHELL_NAME" in
        zsh)  printf '%s/.zshrc\n' "$HOME" ;;
        bash) printf '%s/.bashrc\n' "$HOME" ;;
        *)    printf '\n' ;;
    esac
}

shell_helper_file() {
    case "$SHELL_NAME" in
        zsh)  printf '%s/craft-rice/shell.zsh\n' "$(cr_config_home)" ;;
        bash) printf '%s/craft-rice/shell.bash\n' "$(cr_config_home)" ;;
        *)    printf '\n' ;;
    esac
}

# install_shell — must run after backup_begin.
install_shell() {
    local rc helper src

    case "$SHELL_NAME" in
        fish)
            local target
            target="$(cr_config_home)/fish/config.fish"
            backup_parent_if_symlink "$target"
            backup_path "$target"
            run mkdir -p "$(dirname "$target")"
            run cp -- "$CR_ROOT/config/shell/fish/config.fish" "$target"
            journal_add file "$target"
            record_managed "$target"
            record_dir "$(dirname "$target")"
            ok "Installed fish config"
            ;;

        zsh|bash)
            rc="$(shell_rc_file)"
            helper="$(shell_helper_file)"
            src="$CR_ROOT/config/shell/$SHELL_NAME/shell.$SHELL_NAME"

            # The helper is fully owned by craft-rice.
            backup_path "$helper"
            run mkdir -p "$(dirname "$helper")"
            run cp -- "$src" "$helper"
            journal_add file "$helper"

            # The rc file is shared: copy it, then append a marked block.
            backup_copy_path "$rc"
            run mkdir -p "$(dirname "$rc")"
            run touch "$rc"

            if [ "$DRY_RUN" = "1" ]; then
                printf '%s[dry-run]%s append craft-rice block to %s\n' "$C_DIM" "$C_RESET" "$rc"
            else
                if grep -qF "$CR_BLOCK_START" "$rc" 2>/dev/null; then
                    debug "craft-rice block already present in $rc"
                else
                    if [ -s "$rc" ] && [ "$(tail -c 1 "$rc" | wc -l | tr -d ' ')" = "0" ]; then
                        printf '\n' >>"$rc"
                    fi
                    {
                        printf '%s\n' "$CR_BLOCK_START"
                        printf '# Added by craft-rice. Remove with: craft-rice uninstall\n'
                        printf '[ -f %q ] && . %q\n' "$helper" "$helper"
                        printf '%s\n' "$CR_BLOCK_END"
                    } >>"$rc"
                fi
            fi
            record_managed "$helper"
            record_block "$rc"
            record_dir "$(dirname "$helper")"
            ok "Installed $SHELL_NAME integration in $rc"
            ;;
    esac
}

# remove_shell_block FILE — strips the marked block, leaves everything else.
remove_shell_block() {
    local file="$1" tmp
    [ -f "$file" ] || return 0
    grep -qF "$CR_BLOCK_START" "$file" 2>/dev/null || return 0

    tmp="$(mktemp "${TMPDIR:-/tmp}/craft-rice-rc.XXXXXX")"
    awk -v start="$CR_BLOCK_START" -v end="$CR_BLOCK_END" '
        $0 == start { skip = 1; next }
        $0 == end   { skip = 0; next }
        !skip       { print }
    ' "$file" >"$tmp"

    # Write through the existing inode so permissions and symlinks survive.
    cat -- "$tmp" >"$file"
    rm -f -- "$tmp"
}

# shell_block_present FILE
shell_block_present() {
    [ -f "$1" ] && grep -qF "$CR_BLOCK_START" "$1" 2>/dev/null
}
