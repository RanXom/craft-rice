# shellcheck shell=bash
# craft-rice — backup and restore engine
#
# Every path craft-rice is about to touch is moved into
#   ~/.local/state/craft-rice/backups/<id>/files/<n>
# and recorded in manifest.tsv. A standalone restore.sh is generated next to
# it, so the originals can be recovered even if craft-rice itself is deleted.

BACKUP_ID=""
BACKUP_DIR=""
BACKUP_MANIFEST=""
BACKUP_INDEX=0
BACKUP_ACTIVE=0
CR_LAST_CONFLICT_DIR=""

backup_begin() {
    local stamp
    stamp="$(date '+%Y%m%d-%H%M%S')"
    BACKUP_ID="${stamp}-$$"
    BACKUP_DIR="$(cr_backup_root)/$BACKUP_ID"
    BACKUP_MANIFEST="$BACKUP_DIR/manifest.tsv"
    BACKUP_INDEX=0

    if [ "$DRY_RUN" = "1" ]; then
        debug "dry-run: would create backup at $BACKUP_DIR"
        return 0
    fi

    mkdir -p "$BACKUP_DIR/files"
    : >"$BACKUP_MANIFEST"
    cat >"$BACKUP_DIR/meta.env" <<EOF
CRAFT_RICE_VERSION=$CR_VERSION
BACKUP_ID=$BACKUP_ID
CREATED_AT=$(date -Iseconds)
DISTRO=$DISTRO_NAME
DISTRO_FAMILY=$DISTRO_FAMILY
SHELL=$SHELL_NAME
HOME=$HOME
EOF
    BACKUP_ACTIVE=1
    # Point at the in-progress backup so an interrupted install can be rolled
    # back even if it never finished.
    ln -sfn "$BACKUP_DIR" "$(cr_backup_root)/current"
    ok "Backup directory: $BACKUP_DIR"
}

# backup_path TARGET
# Moves TARGET (file, directory, symlink, or nothing) into the backup.
backup_path() {
    local target="$1" action dest
    [ -n "$target" ] || return 0

    if [ -L "$target" ]; then
        action="symlink"
    elif [ -d "$target" ]; then
        action="dir"
    elif [ -e "$target" ]; then
        action="file"
    else
        action="absent"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s backup %-8s %s\n' "$C_DIM" "$C_RESET" "$action" "$target"
        return 0
    fi

    BACKUP_INDEX=$((BACKUP_INDEX + 1))
    printf '%s\t%s\t%s\n' "$BACKUP_INDEX" "$action" "$(tsv_escape "$target")" >>"$BACKUP_MANIFEST"

    if [ "$action" = "absent" ]; then
        debug "nothing to back up: $target"
        return 0
    fi

    dest="$BACKUP_DIR/files/$BACKUP_INDEX"
    mv -- "$target" "$dest" || die "Could not move $target into the backup"
    debug "backed up $action: $target -> $dest"
}

# backup_note_created_dir TARGET
# Record a directory craft-rice is about to create (as "absent"), so a failed
# install removes it again. Does nothing when the directory already exists.
backup_note_created_dir() {
    local target="$1"
    [ -n "$target" ] || return 0
    [ -e "$target" ] && return 0
    [ "$DRY_RUN" = "1" ] && return 0
    BACKUP_INDEX=$((BACKUP_INDEX + 1))
    printf '%s\t%s\t%s\n' "$BACKUP_INDEX" "absent" "$(tsv_escape "$target")" >>"$BACKUP_MANIFEST"
    return 0
}

# backup_copy_path TARGET
# Like backup_path, but copies instead of moving. Used for shell rc files that
# we append to rather than replace.
backup_copy_path() {
    local target="$1" action dest
    [ -n "$target" ] || return 0

    if [ -L "$target" ]; then
        action="symlink"
    elif [ -d "$target" ]; then
        action="dir"
    elif [ -e "$target" ]; then
        action="file"
    else
        action="absent"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s backup-copy %-8s %s\n' "$C_DIM" "$C_RESET" "$action" "$target"
        return 0
    fi

    BACKUP_INDEX=$((BACKUP_INDEX + 1))
    printf '%s\t%s\t%s\n' "$BACKUP_INDEX" "$action" "$(tsv_escape "$target")" >>"$BACKUP_MANIFEST"

    [ "$action" = "absent" ] && return 0

    dest="$BACKUP_DIR/files/$BACKUP_INDEX"
    if [ "$action" = "symlink" ]; then
        cp -P -- "$target" "$dest"
    elif [ "$action" = "dir" ]; then
        cp -a -- "$target" "$dest"
    else
        cp -p -- "$target" "$dest"
    fi
    debug "copied $action into backup: $target -> $dest"
}

# backup_parent_if_symlink TARGET
# If TARGET's parent directory is a symlink (stow/chezmoi style), back up the
# symlink itself and replace it with a real directory. The contents stay in the
# backup and are restored on uninstall.
backup_parent_if_symlink() {
    local target="$1" parent
    parent="$(dirname "$target")"

    # Never move the XDG roots themselves; preflight warns about those.
    case "$parent" in
        "$HOME/.config"|"$HOME/.local"|"$HOME/.local/share"|"$HOME/.local/bin"|"$HOME") return 0 ;;
    esac

    if [ -L "$parent" ]; then
        warn "Parent directory is a symlink; replacing it with a real directory: $parent"
        backup_path "$parent"
        run mkdir -p "$parent"
        journal_add dir "$parent"
    fi
}

# Prints the backup action recorded for TARGET (file/dir/symlink/absent/copy),
# or nothing when the path was never backed up.
backup_action_for() {
    local target="$1"
    [ -f "$BACKUP_MANIFEST" ] || return 0
    awk -F'\t' -v t="$target" '$3 == t { print $2; exit }' "$BACKUP_MANIFEST"
}

# Backup a list of paths (one per line on stdin).
backup_paths() {
    local p
    while IFS= read -r p; do
        [ -n "$p" ] && backup_path "$p"
    done
}

backup_finish() {
    [ "$BACKUP_ACTIVE" = "1" ] || return 0
    [ "$DRY_RUN" = "1" ] && return 0
    generate_restore_script
    ok "Backed up $(wc -l <"$BACKUP_MANIFEST" | tr -d ' ') path(s)"
}

# merge_previous_backup OLD_DIR
#
# Used when reinstalling over an existing install. The paths just backed up are
# craft-rice's own files, not the user's originals. For every path that OLD_DIR
# already holds, drop the new copy and reuse the true original instead, so an
# uninstall after a reinstall still restores what the user actually had.
merge_previous_backup() {
    local old="$1" old_manifest="$1/manifest.tsv"
    [ -n "$old" ] && [ -f "$old_manifest" ] || return 0
    [ "$DRY_RUN" = "1" ] && return 0
    [ -f "$BACKUP_MANIFEST" ] || return 0

    local work
    work="$(mktemp -d "${TMPDIR:-/tmp}/craft-rice-merge.XXXXXX")"
    mkdir -p "$work/files"

    local idx action target next=0 reused=0 kept=0

    # Anything the previous install already knows about keeps the old record,
    # including "absent": that path did not exist before craft-rice touched it.
    while IFS=$'\t' read -r idx action target; do
        [ -n "$idx" ] || continue
        if awk -F'\t' -v t="$target" '$3 == t { found = 1 } END { exit !found }' "$old_manifest"; then
            continue
        fi
        next=$((next + 1))
        printf '%s\t%s\t%s\n' "$next" "$action" "$target" >>"$work/manifest.tsv"
        [ "$action" = "absent" ] || cp -a -- "$BACKUP_DIR/files/$idx" "$work/files/$next"
        kept=$((kept + 1))
    done <"$BACKUP_MANIFEST"

    # Replay the previous install's verdict for every path it saw.
    while IFS=$'\t' read -r idx action target; do
        [ -n "$idx" ] || continue
        next=$((next + 1))
        printf '%s\t%s\t%s\n' "$next" "$action" "$target" >>"$work/manifest.tsv"
        if [ "$action" != "absent" ] && { [ -e "$old/files/$idx" ] || [ -L "$old/files/$idx" ]; }; then
            cp -a -- "$old/files/$idx" "$work/files/$next"
            reused=$((reused + 1))
        fi
    done <"$old_manifest"

    rm -rf -- "$BACKUP_DIR/files"
    mv -- "$work/files" "$BACKUP_DIR/files"
    mv -f -- "$work/manifest.tsv" "$BACKUP_MANIFEST"
    rmdir -- "$work" 2>/dev/null || rm -rf -- "$work"
    BACKUP_INDEX="$next"
    debug "reused $reused original(s), kept $kept new path(s) from previous install"
}

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------

generate_restore_script() {
    local script="$BACKUP_DIR/restore.sh" state_dir
    state_dir="$(cr_state_dir)"

    {
        printf '#!/usr/bin/env bash\n'
        printf '# Generated by craft-rice %s on %s\n' "$CR_VERSION" "$(date -Iseconds)"
        printf '# Restores every file that craft-rice backed up before installing.\n'
        printf 'set -euo pipefail\n\n'
        printf 'BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
        printf 'STATE_DIR=%q\n' "$state_dir"
        printf 'CONFLICT_DIR="$STATE_DIR/conflicts/restore-$(date +%%Y%%m%%d-%%H%%M%%S)-$$"\n\n'
        cat <<'FUNC'
say()  { printf '%s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }

move_aside() {
    local target="$1" rel
    [ -e "$target" ] || [ -L "$target" ] || return 0
    rel="${target#/}"
    mkdir -p "$CONFLICT_DIR/$(dirname "$rel")"
    mv -- "$target" "$CONFLICT_DIR/$rel"
    warn "Existing path moved aside: $target -> $CONFLICT_DIR/$rel"
}
FUNC
        cat <<'LOOP'

while IFS=$'\t' read -r idx action target; do
    [ -n "${idx:-}" ] || continue
    [ "$action" = "absent" ] && continue
    src="$BACKUP_DIR/files/$idx"
    [ -e "$src" ] || [ -L "$src" ] || { warn "Missing backup file: $src"; continue; }
    move_aside "$target"
    mkdir -p "$(dirname "$target")"
    mv -- "$src" "$target"
    say "restored $target"
done <<'MANIFEST'
LOOP
        cat "$BACKUP_MANIFEST"
        printf 'MANIFEST\n\n'
        printf 'rmdir "$BACKUP_DIR/files" 2>/dev/null || true\n'
        printf 'say "Restore complete."\n'
    } >"$script"

    chmod +x "$script"
}

# restore_backup BACKUP_DIR
restore_backup() {
    local dir="$1" manifest="$1/manifest.tsv" idx action target src
    [ -f "$manifest" ] || { warn "No manifest in $dir"; return 1; }

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s would restore originals from %s\n' "$C_DIM" "$C_RESET" "$dir"
        return 0
    fi

    local conflict_dir
    conflict_dir="$(cr_state_dir)/conflicts/restore-$(date '+%Y%m%d-%H%M%S')-$$"
    CR_LAST_CONFLICT_DIR="$conflict_dir"
    local restored=0

    # Reverse order, so nested paths unwind cleanly.
    while IFS=$'\t' read -r idx action target; do
        [ -n "${idx:-}" ] || continue
        [ "$action" = "absent" ] && continue

        # Caller may have already handled this path (shell rc blocks).
        local skip
        for skip in ${CR_RESTORE_SKIP[@]+"${CR_RESTORE_SKIP[@]}"}; do
            [ "$skip" = "$target" ] && continue 2
        done

        src="$dir/files/$idx"
        if [ ! -e "$src" ] && [ ! -L "$src" ]; then
            warn "Backup file missing: $src"
            continue
        fi

        if [ -e "$target" ] || [ -L "$target" ]; then
            local rel="${target#/}"
            mkdir -p "$conflict_dir/$(dirname "$rel")"
            mv -- "$target" "$conflict_dir/$rel"
            warn "Moved current file aside: $target"
        fi

        mkdir -p "$(dirname "$target")"
        mv -- "$src" "$target"
        debug "restored $target"
        restored=$((restored + 1))
    done < <(tac "$manifest" 2>/dev/null || tail -r "$manifest")

    ok "Restored $restored path(s)"
    return 0
}

# ---------------------------------------------------------------------------
# Journal — lets an interrupted install roll itself back
# ---------------------------------------------------------------------------

journal_path() { printf '%s/journal.tsv\n' "$(cr_state_dir)"; }

journal_reset() {
    [ "$DRY_RUN" = "1" ] && return 0
    : >"$(journal_path)"
}

journal_add() {
    local kind="$1" path="$2"
    [ "$DRY_RUN" = "1" ] && return 0
    printf '%s\t%s\n' "$kind" "$(tsv_escape "$path")" >>"$(journal_path)"
}

# reverse_lines FILE — newest line first (tac, with a BSD tail -r fallback).
reverse_lines() {
    tac "$1" 2>/dev/null || tail -r "$1"
}

# rollback_from_backup DIR
#
# Undo a partially finished install using its backup manifest:
#   1. delete every path the manifest recorded as "absent" (we created it),
#   2. move the originals back, moving anything we added aside.
rollback_from_backup() {
    local dir="$1" manifest="$1/manifest.tsv"
    [ -n "$dir" ] && [ -f "$manifest" ] || return 1

    local idx action target
    while IFS=$'\t' read -r idx action target; do
        [ -n "$idx" ] || continue
        [ "$action" = "absent" ] || continue
        [ -e "$target" ] || [ -L "$target" ] || continue
        rm -rf -- "$target" || warn "Could not remove $target"
    done < <(reverse_lines "$manifest")

    CR_RESTORE_SKIP=()
    restore_backup "$dir"
}
