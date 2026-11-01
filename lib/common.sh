# shellcheck shell=bash
# craft-rice — shared helpers
#
# Sourced by bin/craft-rice. Not executable on its own.

CR_VERSION="1.0.0"
CR_NAME="craft-rice"

# Filled in by bin/craft-rice.
CR_ROOT="${CR_ROOT:-}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
NO_PACKAGES="${NO_PACKAGES:-0}"
MINIMAL="${MINIMAL:-0}"
FORCE="${FORCE:-0}"
PURGE_PACKAGES="${PURGE_PACKAGES:-0}"
PURGE_STATE="${PURGE_STATE:-0}"
VERBOSE="${VERBOSE:-0}"
PREVIEW_MODE="${PREVIEW_MODE:-}"
PREVIEW_OUT="${PREVIEW_OUT:-}"
PREVIEW_INDIV="${PREVIEW_INDIV:-0}"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

cr_home() { printf '%s\n' "${HOME:?HOME is not set}"; }
cr_config_home() { printf '%s\n' "${XDG_CONFIG_HOME:-$(cr_home)/.config}"; }
cr_data_home() { printf '%s\n' "${XDG_DATA_HOME:-$(cr_home)/.local/share}"; }
cr_state_home() { printf '%s\n' "${XDG_STATE_HOME:-$(cr_home)/.local/state}"; }
cr_cache_home() { printf '%s\n' "${XDG_CACHE_HOME:-$(cr_home)/.cache}"; }
cr_state_dir() { printf '%s\n' "$(cr_state_home)/$CR_NAME"; }
cr_backup_root() { printf '%s\n' "$(cr_state_dir)/backups"; }
cr_install_record() { printf '%s\n' "$(cr_state_dir)/installed.tsv"; }
cr_log_file() { printf '%s\n' "$(cr_state_dir)/craft-rice.log"; }

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

_log_line() {
    local level="$1"; shift
    local msg="$*"
    local dir
    dir="$(cr_state_dir)"
    if [ -d "$dir" ]; then
        printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" >>"$(cr_log_file)" 2>/dev/null || true
    fi
}

log()  { printf '%s\n' "$*"; _log_line INFO "$*"; }
info() { printf '%s%s%s\n' "$C_BLUE" "$*" "$C_RESET"; _log_line INFO "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; _log_line OK "$*"; }
warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; _log_line WARN "$*"; }
err()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; _log_line ERROR "$*"; }
die()  { err "$*"; exit 1; }

debug() {
    [ "$VERBOSE" = "1" ] || return 0
    printf '%s· %s%s\n' "$C_DIM" "$*" "$C_RESET" >&2
    _log_line DEBUG "$*"
}

section() {
    printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"
    _log_line SECTION "$*"
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

# ask_yes_no "question" [default: y|n]
ask_yes_no() {
    local prompt="$1" default="${2:-n}" answer
    if [ "$ASSUME_YES" = "1" ]; then
        [ "$default" = "y" ] && return 0 || return 1
    fi
    if [ ! -t 0 ]; then
        [ "$default" = "y" ] && return 0 || return 1
    fi
    if [ "$default" = "y" ]; then
        printf '%s [Y/n] ' "$prompt"
    else
        printf '%s [y/N] ' "$prompt"
    fi
    read -r answer || answer=""
    answer="${answer:-$default}"
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# ask_choice "question" "opt1" "opt2" ... ; result in $REPLY
ask_choice() {
    local prompt="$1"; shift
    local -a opts=("$@")
    local i answer
    printf '%s\n' "$prompt"
    for i in "${!opts[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${opts[$i]}"
    done
    while true; do
        printf 'Choose [1-%d]: ' "${#opts[@]}"
        read -r answer || answer=""
        if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le "${#opts[@]}" ]; then
            REPLY="${opts[$((answer - 1))]}"
            return 0
        fi
    done
}

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

# run CMD... — honours --dry-run.
run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
        return 0
    fi
    debug "exec: $*"
    "$@"
}

# run_shell "command string" — for commands that need a shell.
run_shell() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$1"
        return 0
    fi
    debug "exec-sh: $1"
    bash -c "$1"
}

# ---------------------------------------------------------------------------
# Hashing
# ---------------------------------------------------------------------------

sha256_of() {
    local file="$1"
    if have sha256sum; then
        sha256sum -- "$file" | awk '{print $1}'
    elif have shasum; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    elif have openssl; then
        openssl dgst -sha256 -- "$file" | awk '{print $NF}'
    else
        printf 'unavailable\n'
    fi
}

# ---------------------------------------------------------------------------
# Locking (portable: mkdir + PID, works without flock)
# ---------------------------------------------------------------------------

cr_lock() {
    local dir pidfile pid
    dir="$(cr_state_dir)"
    mkdir -p "$dir"
    pidfile="$dir/lock"

    if [ -d "$pidfile" ]; then
        pid="$(cat "$pidfile/pid" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            die "Another craft-rice process is running (pid $pid). If that is wrong, remove $pidfile"
        fi
        warn "Removing stale lock from pid ${pid:-unknown}"
        rm -rf -- "$pidfile"
    fi

    mkdir -- "$pidfile" || die "Could not create lock: $pidfile"
    printf '%s\n' "$$" >"$pidfile/pid"
    CR_LOCK_DIR="$pidfile"
}

cr_unlock() {
    if [ -n "${CR_LOCK_DIR:-}" ] && [ -d "$CR_LOCK_DIR" ]; then
        rm -rf -- "$CR_LOCK_DIR"
    fi
    CR_LOCK_DIR=""
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

trim() {
    local s="$*"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s\n' "$s"
}

# Escape a value for a TSV field.
tsv_escape() { printf '%s' "$1" | tr '\t\n' '  '; }

# Read the first field of /etc/os-release without sourcing it.
os_release_field() {
    local key="$1" file="${2:-/etc/os-release}"
    [ -r "$file" ] || return 0
    awk -F= -v k="$key" '
        $1 == k {
            v = substr($0, index($0, "=") + 1)
            gsub(/^["'"'"']|["'"'"']$/, "", v)
            print v
            exit
        }
    ' "$file"
}

human_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
        awk -v b="$bytes" 'BEGIN{printf "%.1f GiB", b/1073741824}'
    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
        awk -v b="$bytes" 'BEGIN{printf "%.1f MiB", b/1048576}'
    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
        awk -v b="$bytes" 'BEGIN{printf "%.1f KiB", b/1024}'
    else
        printf '%s B\n' "$bytes"
    fi
}
