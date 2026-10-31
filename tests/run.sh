#!/usr/bin/env bash
# craft-rice — test suite
#
# Runs every scenario in throwaway HOME directories. Nothing outside
# tests/tmp is touched, and no packages are installed.
#
#   ./tests/run.sh           all tests
#   ./tests/run.sh -v        keep temporary directories and show commands
#
# Exit code 0 means everything passed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-/tmp}/craft-rice-tests"
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

PASS=0
FAIL=0
FAILED_NAMES=()

say()  { printf '%s\n' "$*"; }
head1() { printf '\n\033[1m%s\033[0m\n' "$*"; }
pass() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$*"); printf '  \033[31m✗\033[0m %s\n' "$*"; }

ok() { if "$@" >/dev/null 2>&1; then return 0; else return 1; fi; }

assert_present() {
    if [ -e "$1" ] || [ -L "$1" ]; then pass "${2:-exists: $1}"; else fail "${2:-missing: $1}"; fi
}
assert_absent() {
    if [ ! -e "$1" ] && [ ! -L "$1" ]; then pass "${2:-absent: $1}"; else fail "${2:-still present: $1}"; fi
}
assert_eq() {
    if [ "$1" = "$2" ]; then pass "${3:-equal}"; else fail "${3:-not equal} (got '$1', want '$2')"; fi
}
assert_contains() {
    if grep -qF -- "$2" "$1" 2>/dev/null; then pass "${3:-contains: $2}"; else fail "${3:-does not contain: $2}"; fi
}
assert_not_contains() {
    if grep -qF -- "$2" "$1" 2>/dev/null; then fail "${3:-still contains: $2}"; else pass "${3:-does not contain: $2}"; fi
}

new_home() {
    local dir="$TMP_BASE/$1"
    rm -rf "$dir"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
}

# run_cr HOME [args...]
# GSETTINGS_BACKEND=memory keeps the GTK theme changes inside the test process,
# so running the suite never touches the live desktop's dconf.
run_cr() {
    local home="$1"; shift
    HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache" \
    GSETTINGS_BACKEND=memory \
        "$ROOT/install.sh" "$@" >"$home/.last.log" 2>&1
    local rc=$?
    [ "$VERBOSE" = "1" ] && { printf '\n--- %s %s ---\n' "$home" "$*"; cat "$home/.last.log"; }
    return $rc
}

niri_available() { command -v niri >/dev/null 2>&1; }

validate_config() {
    local file="$1"
    niri_available || return 0
    niri validate -c "$file" >/dev/null 2>&1
}

rm -rf "$TMP_BASE"
mkdir -p "$TMP_BASE"

# ---------------------------------------------------------------------------
head1 "1. Syntax"
# ---------------------------------------------------------------------------
for f in "$ROOT/install.sh" "$ROOT/bin/craft-rice" "$ROOT"/lib/*.sh; do
    if ok bash -n "$f"; then pass "bash -n $(basename "$f")"; else fail "bash -n $f"; fi
done
if ok python3 -m py_compile "$ROOT/lib/outputs.py"; then
    pass "python compile outputs.py"
else
    fail "python compile outputs.py"
fi
rm -rf "$ROOT/lib/__pycache__"

# ---------------------------------------------------------------------------
head1 "2. Fresh install (bash)"
# ---------------------------------------------------------------------------
H="$(new_home fresh)"
printf '# my bashrc\nexport KEEP=1\n' >"$H/.bashrc"
mkdir -p "$H/.config/kitty"
printf '# my kitty\nfont_size 12\n' >"$H/.config/kitty/kitty.conf"

if CRAFT_RICE_SHELL=bash run_cr "$H" install --yes --no-packages; then pass "install exits 0"; else fail "install exits 0"; fi

assert_present "$H/.config/niri/config.kdl" "niri config written"
assert_present "$H/.config/niri/animations/glide.kdl" "animations copied"
assert_present "$H/.config/niri/outputs.kdl" "outputs written"
assert_present "$H/.config/niri/extras.kdl" "extras written"
assert_present "$H/.config/noctalia/settings.toml" "noctalia settings"
assert_present "$H/.config/noctalia/plugins/slowbongo/manifest.json" "noctalia plugin"
assert_present "$H/.config/kitty/kitty.conf" "kitty config"
assert_present "$H/.config/kitty/themes/noctalia.conf" "kitty theme"
assert_present "$H/.config/fastfetch/config.jsonc" "fastfetch config"
assert_present "$H/.config/starship.toml" "starship config"
assert_present "$H/.local/share/fonts/Monocraft.ttc" "Monocraft font"
assert_present "$H/.local/share/icons/Pixel-Theme/index.theme" "Pixel-Theme icons"
assert_present "$H/.local/share/icons/JuxCursor/cursors/left_ptr" "JuxCursor cursors"
assert_present "$H/.local/share/backgrounds/craft-rice/00-arch-black-4k.png" "wallpapers"
assert_present "$H/.local/bin/craft-rice-oniri" "oniri wrapper"
assert_present "$H/.local/bin/craft-rice-polkit" "polkit wrapper"
assert_present "$H/.local/state/craft-rice/installed.tsv" "install record"
assert_present "$H/.local/state/craft-rice/backups/current/manifest.tsv" "backup manifest"
assert_present "$H/.local/state/craft-rice/backups/current/restore.sh" "standalone restore.sh"

assert_contains "$H/.bashrc" "# >>> craft-rice >>>" "bash block added"
assert_contains "$H/.bashrc" "export KEEP=1" "existing bashrc kept"
assert_not_contains "$H/.config/niri/config.kdl" "@SHELL@" "shell token rendered"
assert_contains "$H/.config/niri/config.kdl" "kitty bash -i" "niri binds use bash"

if validate_config "$H/.config/niri/config.kdl"; then pass "niri config validates"; else fail "niri config validates"; fi

# Refreshing the monitor layout must not leave junk next to the config.
if run_cr "$H" outputs; then pass "outputs exits 0"; else fail "outputs exits 0"; fi
assert_present "$H/.local/state/craft-rice/outputs" "output layout backup kept in state"
assert_absent "$(find "$H/.config/niri" -maxdepth 1 -name 'outputs.kdl.bak.*' -print -quit)" "no backup litter in config dir"

# skips in a non-tty
if run_cr "$H" status; then pass "status exits 0"; else fail "status exits 0"; fi
assert_contains "$H/.last.log" "Status: installed" "status reports installed"

# ---------------------------------------------------------------------------
head1 "3. Uninstall restores originals"
# ---------------------------------------------------------------------------
if run_cr "$H" uninstall --yes; then pass "uninstall exits 0"; else fail "uninstall exits 0"; fi

assert_present "$H/.bashrc" "bashrc still exists"
assert_eq "$(cat "$H/.bashrc")" $'# my bashrc\nexport KEEP=1' "bashrc restored byte for byte"
assert_eq "$(cat "$H/.config/kitty/kitty.conf")" $'# my kitty\nfont_size 12' "kitty.conf restored"
assert_absent "$H/.config/niri" "niri dir removed"
assert_absent "$H/.config/noctalia" "noctalia dir removed"
assert_absent "$H/.local/share/fonts/Monocrit.ttc" "no stray font"
assert_absent "$H/.local/share/fonts/Monocraft.ttc" "font removed"
assert_absent "$H/.local/share/icons/Pixel-Theme" "icons removed"
assert_absent "$H/.local/share/icons/JuxCursor" "cursors removed"
assert_absent "$H/.local/bin/craft-rice" "command removed"
assert_absent "$H/.local/share/craft-rice" "tool copy removed"
assert_absent "$H/.local/state/craft-rice/installed.tsv" "install record removed"
assert_present "$H/.local/state/craft-rice/backups/current/restore.sh" "backups kept"

# ---------------------------------------------------------------------------
head1 "4. Reinstall then uninstall still restores the true originals"
# ---------------------------------------------------------------------------
H="$(new_home reinstall)"
printf '# original rc\n' >"$H/.bashrc"
mkdir -p "$H/.config/kitty"
printf '# original kitty\n' >"$H/.config/kitty/kitty.conf"

CRAFT_RICE_SHELL=bash run_cr "$H" install --yes --no-packages; i1=$?
CRAFT_RICE_SHELL=bash run_cr "$H" install --yes --no-packages --force; i2=$?
if [ "$i1" = "0" ] && [ "$i2" = "0" ]; then pass "install twice"; else fail "install twice"; fi
run_cr "$H" uninstall --yes; u=$?
if [ "$u" = "0" ]; then pass "uninstall after reinstall"; else fail "uninstall after reinstall"; fi
assert_eq "$(cat "$H/.bashrc")" "# original rc" "bashrc still the user's original"
assert_eq "$(cat "$H/.config/kitty/kitty.conf")" "# original kitty" "kitty.conf still the user's original"
assert_absent "$H/.config/niri" "no craft-rice niri dir left"
assert_absent "$H/.local/share/craft-rice" "no craft-rice tool dir left"

# ---------------------------------------------------------------------------
head1 "5. Dry run changes nothing"
# ---------------------------------------------------------------------------
H="$(new_home dry)"
printf '# untouched\n' >"$H/.bashrc"
run_cr "$H" install --yes --no-packages --dry-run; d=$?
if [ "$d" = "0" ]; then pass "dry run exits 0"; else fail "dry run exits 0"; fi
assert_eq "$(cat "$H/.bashrc")" "# untouched" "bashrc untouched"
assert_absent "$H/.config/niri" "no files created"
assert_absent "$H/.local/state/craft-rice/installed.tsv" "no install record"

# ---------------------------------------------------------------------------
head1 "6. Zsh: mark, keep user edits, remove only our block"
# ---------------------------------------------------------------------------
H="$(new_home zsh)"
printf '# zshrc\nalias g=git\n' >"$H/.zshrc"
CRAFT_RICE_SHELL=zsh run_cr "$H" install --yes --no-packages; z=$?
if [ "$z" = "0" ]; then pass "zsh install"; else fail "zsh install"; fi
assert_contains "$H/.zshrc" "# >>> craft-rice >>>" "zsh block added"
assert_contains "$H/.config/craft-rice/shell.zsh" "zoxide init zsh" "zsh helper written"
assert_contains "$H/.config/niri/config.kdl" "kitty zsh -i" "niri binds use zsh"
printf 'export LATE=1\n' >>"$H/.zshrc"
run_cr "$H" uninstall --yes
assert_not_contains "$H/.zshrc" "# >>> craft-rice >>>" "zsh block removed"
assert_contains "$H/.zshrc" "export LATE=1" "later user edit preserved"
assert_contains "$H/.zshrc" "alias g=git" "original line preserved"
assert_absent "$H/.config/craft-rice" "helper dir removed"

# ---------------------------------------------------------------------------
head1 "7. Fish: config file instead of an rc block"
# ---------------------------------------------------------------------------
H="$(new_home fish)"
CRAFT_RICE_SHELL=fish run_cr "$H" install --yes --no-packages; f=$?
if [ "$f" = "0" ]; then pass "fish install"; else fail "fish install"; fi
assert_present "$H/.config/fish/config.fish" "fish config written"
assert_contains "$H/.config/niri/config.kdl" "kitty fish -i" "niri binds use fish"
assert_absent "$H/.bashrc" "no bashrc block created"
CRAFT_RICE_SHELL=fish run_cr "$H" uninstall --yes
assert_absent "$H/.config/fish/config.fish" "fish config removed"

# ---------------------------------------------------------------------------
head1 "8. HOME with spaces"
# ---------------------------------------------------------------------------
H="$TMP_BASE/home with spaces"
rm -rf "$H"; mkdir -p "$H"
printf '# spaced rc\n' >"$H/.bashrc"
run_cr "$H" install --yes --no-packages; s=$?
if [ "$s" = "0" ]; then pass "install with spaces in HOME"; else fail "install with spaces in HOME"; fi
assert_present "$H/.config/niri/config.kdl" "config written"
if validate_config "$H/.config/niri/config.kdl"; then pass "config validates"; else fail "config validates"; fi
run_cr "$H" uninstall --yes
assert_eq "$(cat "$H/.bashrc")" "# spaced rc" "rc restored"
assert_absent "$H/.config/niri" "niri dir removed"

# ---------------------------------------------------------------------------
head1 "9. Config directory that is a symlink"
# ---------------------------------------------------------------------------
H="$(new_home symlink)"
mkdir -p "$H/.config" "$TMP_BASE/dotfiles/niri"
printf '// mine\n' >"$TMP_BASE/dotfiles/niri/config.kdl"
ln -s "$TMP_BASE/dotfiles/niri" "$H/.config/niri"
run_cr "$H" install --yes --no-packages --force; l=$?
if [ "$l" = "0" ]; then pass "install over symlinked dir"; else fail "install over symlinked dir"; fi
if [ ! -L "$H/.config/niri" ]; then pass "symlink replaced by real dir"; else fail "symlink replaced by real dir"; fi
run_cr "$H" uninstall --yes
if [ -L "$H/.config/niri" ]; then pass "symlink restored"; else fail "symlink restored"; fi
assert_eq "$(cat "$H/.config/niri/config.kdl")" "// mine" "original file behind symlink"

# ---------------------------------------------------------------------------
head1 "10. Failed install rolls itself back"
# ---------------------------------------------------------------------------
if [ "$(id -u)" = "0" ]; then
    say "  (skipped: running as root)"
else
    H="$(new_home fail)"
    mkdir -p "$H/.local/share" "$H/.config/kitty"
    printf '# mine\n' >"$H/.config/kitty/kitty.conf"
    printf '# rc\n' >"$H/.bashrc"
    chmod 500 "$H/.local/share"
    run_cr "$H" install --yes --no-packages; f=$?
    chmod 755 "$H/.local/share"
    if [ "$f" != "0" ]; then pass "install fails as expected"; else fail "install fails as expected"; fi
    assert_eq "$(cat "$H/.config/kitty/kitty.conf")" "# mine" "kitty.conf restored"
    assert_eq "$(cat "$H/.bashrc")" "# rc" "bashrc restored"
    assert_absent "$H/.config/niri" "partial niri config removed"
    assert_absent "$H/.config/noctalia" "partial noctalia config removed"
    assert_absent "$H/.config/craft-rice" "partial helper dir removed"
    assert_absent "$H/.local/state/craft-rice/installed.tsv" "no install record"
fi

# ---------------------------------------------------------------------------
head1 "11. Interrupted install is recoverable"
# ---------------------------------------------------------------------------
H="$(new_home interrupted)"
printf '# rc\n' >"$H/.bashrc"
HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
XDG_STATE_HOME="$H/.local/state" XDG_CACHE_HOME="$H/.cache" \
GSETTINGS_BACKEND=memory \
    "$ROOT/install.sh" install --yes --no-packages >"$H/.last.log" 2>&1 &
PID=$!
sleep 3
kill -9 "$PID" 2>/dev/null
wait "$PID" 2>/dev/null
if [ -f "$H/.local/state/craft-rice/journal.tsv" ] || [ -f "$H/.local/state/craft-rice/installed.tsv.new" ]; then
    pass "interrupted install left a journal"
else
    fail "interrupted install left a journal (finished too fast?)"
fi
run_cr "$H" recover --yes; r=$?
if [ "$r" = "0" ]; then pass "recover exits 0"; else fail "recover exits 0"; fi
assert_eq "$(cat "$H/.bashrc")" "# rc" "bashrc intact after recover"
assert_absent "$H/.config/niri" "partial niri config removed by recover"
assert_absent "$H/.local/state/craft-rice/installed.tsv" "no install record after recover"

# ---------------------------------------------------------------------------
head1 "12. Blur stripping for older Niri"
# ---------------------------------------------------------------------------
H="$(new_home oldniri)"
CRAFT_RICE_SHELL=bash CRAFT_RICE_NIRI_BLUR=0 run_cr "$H" install --yes --no-packages; b=$?
if [ "$b" = "0" ]; then pass "install without blur"; else fail "install without blur"; fi
assert_not_contains "$H/.config/niri/config.kdl" "passes 4" "blur block stripped"
assert_not_contains "$H/.config/niri/config.kdl" "xray" "blur layer rules stripped"
if validate_config "$H/.config/niri/config.kdl"; then pass "stripped config validates"; else fail "stripped config validates"; fi

# ---------------------------------------------------------------------------
head1 "13. Uninstall when not installed"
# ---------------------------------------------------------------------------
H="$(new_home empty)"
run_cr "$H" uninstall --yes; e=$?
if [ "$e" != "0" ]; then pass "uninstall refuses when not installed"; else fail "uninstall refuses when not installed"; fi
assert_present "$H" "home still there"

# ---------------------------------------------------------------------------
say ""
if [ "$FAIL" -eq 0 ]; then
    printf '\033[32mAll %d checks passed.\033[0m\n' "$PASS"
    [ "$VERBOSE" = "1" ] || rm -rf "$TMP_BASE"
    exit 0
else
    printf '\033[31m%d passed, %d failed:\033[0m\n' "$PASS" "$FAIL"
    for name in "${FAILED_NAMES[@]}"; do printf '  - %s\n' "$name"; done
    printf 'Temporary directories kept in %s\n' "$TMP_BASE"
    exit 1
fi
