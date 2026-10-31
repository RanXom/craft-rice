# shellcheck shell=bash
# craft-rice — system detection

DISTRO_ID=""
DISTRO_LIKE=""
DISTRO_NAME=""
DISTRO_FAMILY="unknown"
PKG_MANAGER=""
PKG_INSTALL_CMD=""
PKG_UPDATE_CMD=""
PKG_REMOVE_CMD=""
ARCH=""
SHELL_NAME=""
NIRI_VERSION=""
NIRI_HAS_BLUR=1
NOCTALIA_VERSION=""

detect_arch() {
    ARCH="$(uname -m)"
}

detect_distro() {
    DISTRO_ID="$(os_release_field ID)"
    DISTRO_LIKE="$(os_release_field ID_LIKE)"
    DISTRO_NAME="$(os_release_field PRETTY_NAME)"
    [ -n "$DISTRO_NAME" ] || DISTRO_NAME="${DISTRO_ID:-Unknown Linux}"

    local id_lower like_lower
    id_lower="$(printf '%s' "$DISTRO_ID" | tr '[:upper:]' '[:lower:]')"
    like_lower="$(printf '%s' "$DISTRO_LIKE" | tr '[:upper:]' '[:lower:]')"

    case " $id_lower $like_lower " in
        *" arch "*|*" cachyos "*|*" endeavouros "*|*" manjaro "*|*" garuda "*|*" artix "*)
            DISTRO_FAMILY="arch" ;;
        *" fedora "*|*" rhel "*|*" centos "*|*" nobara "*|*" rocky "*|*" almalinux "*)
            DISTRO_FAMILY="fedora" ;;
        *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*|*" elementary "*|*" zorin "*|*" kali "*|*" neon "*)
            DISTRO_FAMILY="debian" ;;
        *" opensuse "*|*" suse "*|*" sles "*)
            DISTRO_FAMILY="opensuse" ;;
        *" void "*)
            DISTRO_FAMILY="void" ;;
        *" alpine "*|*" chimera "*)
            DISTRO_FAMILY="alpine" ;;
        *" gentoo "*|*" funtoo "*)
            DISTRO_FAMILY="gentoo" ;;
        *" solus "*)
            DISTRO_FAMILY="solus" ;;
        *" nixos "*)
            DISTRO_FAMILY="nixos" ;;
        *)
            DISTRO_FAMILY="unknown" ;;
    esac

    # Prefer the actual package manager over the family guess.
    if have pacman; then
        PKG_MANAGER="pacman"
        PKG_INSTALL_CMD="sudo pacman -S --needed --noconfirm"
        PKG_UPDATE_CMD="sudo pacman -Sy"
        PKG_REMOVE_CMD="sudo pacman -Rns --noconfirm"
    elif have dnf; then
        PKG_MANAGER="dnf"
        PKG_INSTALL_CMD="sudo dnf install -y"
        PKG_UPDATE_CMD="sudo dnf makecache"
        PKG_REMOVE_CMD="sudo dnf remove -y"
    elif have apt-get; then
        PKG_MANAGER="apt"
        PKG_INSTALL_CMD="sudo apt-get install -y"
        PKG_UPDATE_CMD="sudo apt-get update"
        PKG_REMOVE_CMD="sudo apt-get remove -y"
    elif have zypper; then
        PKG_MANAGER="zypper"
        PKG_INSTALL_CMD="sudo zypper --non-interactive install"
        PKG_UPDATE_CMD="sudo zypper --non-interactive refresh"
        PKG_REMOVE_CMD="sudo zypper --non-interactive remove"
    elif have xbps-install; then
        PKG_MANAGER="xbps"
        PKG_INSTALL_CMD="sudo xbps-install -y"
        PKG_UPDATE_CMD="sudo xbps-install -S"
        PKG_REMOVE_CMD="sudo xbps-remove -R"
    elif have apk; then
        PKG_MANAGER="apk"
        PKG_INSTALL_CMD="sudo apk add"
        PKG_UPDATE_CMD="sudo apk update"
        PKG_REMOVE_CMD="sudo apk del"
    elif have emerge; then
        PKG_MANAGER="emerge"
        PKG_INSTALL_CMD="sudo emerge --noreplace"
        PKG_UPDATE_CMD=""
        PKG_REMOVE_CMD="sudo emerge --unmerge"
    elif have eopkg; then
        PKG_MANAGER="eopkg"
        PKG_INSTALL_CMD="sudo eopkg install -y"
        PKG_UPDATE_CMD="sudo eopkg update-repo"
        PKG_REMOVE_CMD="sudo eopkg remove -y"
    elif have nix-env; then
        PKG_MANAGER="nix"
        PKG_INSTALL_CMD=""
        PKG_UPDATE_CMD=""
    else
        PKG_MANAGER=""
        PKG_INSTALL_CMD=""
        PKG_UPDATE_CMD=""
    fi
}

# Prints a short one-line summary.
distro_summary() {
    printf '%s (%s, %s)\n' "$DISTRO_NAME" "${DISTRO_FAMILY}" "${ARCH}"
}

# ---------------------------------------------------------------------------
# Shell
# ---------------------------------------------------------------------------

detect_shell() {
    local login available=() candidate=""

    login="$(basename "${SHELL:-}")"

    have fish && available+=("fish")
    have zsh && available+=("zsh")
    have bash && available+=("bash")

    # Explicit override wins, e.g. CRAFT_RICE_SHELL=zsh ./install.sh
    if [ -n "${CRAFT_RICE_SHELL:-}" ]; then
        case "$CRAFT_RICE_SHELL" in
            fish|zsh|bash) SHELL_NAME="$CRAFT_RICE_SHELL"; return 0 ;;
            *) die "CRAFT_RICE_SHELL must be fish, zsh or bash" ;;
        esac
    fi

    case "$login" in
        fish|zsh|bash) candidate="$login" ;;
    esac

    # Nothing usable? Fall back to bash, which is always present.
    if [ "${#available[@]}" -eq 0 ]; then
        warn "No supported shell found; falling back to bash"
        SHELL_NAME="bash"
        return 0
    fi

    # The rice is built around fish. If the user runs zsh/bash, ask.
    if [ "$candidate" != "fish" ] && have fish; then
        section "Shell"
        log "This rice ships with a Fish configuration."
        if [ -n "$candidate" ]; then
            log "Your login shell is ${C_BOLD}${candidate}${C_RESET}."
        else
            log "Your login shell is ${C_BOLD}${login:-unknown}${C_RESET}."
        fi

        if ask_yes_no "Keep ${candidate:-your current shell} instead of switching to Fish?" "y"; then
            SHELL_NAME="${candidate:-bash}"
        else
            SHELL_NAME="fish"
        fi
        return 0
    fi

    if [ -n "$candidate" ]; then
        SHELL_NAME="$candidate"
        return 0
    fi

    # Login shell is something exotic; pick from what is installed.
    section "Shell"
    ask_choice "Which shell should the rice configure?" "${available[@]}"
    SHELL_NAME="$REPLY"
}

# ---------------------------------------------------------------------------
# Niri
# ---------------------------------------------------------------------------

detect_niri() {
    # Escape hatch for testing or for a hand-built Niri:
    #   CRAFT_RICE_NIRI_BLUR=0 craft-rice install
    if [ -n "${CRAFT_RICE_NIRI_BLUR:-}" ]; then
        case "$CRAFT_RICE_NIRI_BLUR" in
            0|no|off) NIRI_HAS_BLUR=0 ;;
            *)        NIRI_HAS_BLUR=1 ;;
        esac
        NIRI_VERSION="${NIRI_VERSION:-$(have niri && niri --version 2>/dev/null | head -n1 || printf 'unknown')}"
        return 0
    fi

    if have niri; then
        NIRI_VERSION="$(niri --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)"
        if [ -z "$NIRI_VERSION" ]; then
            NIRI_VERSION="unknown"
            NIRI_HAS_BLUR=1
            return 0
        fi
        local major minor
        major="${NIRI_VERSION%%.*}"
        minor="${NIRI_VERSION#*.}"
        if [ "$major" -gt 26 ] || { [ "$major" -eq 26 ] && [ "$minor" -ge 4 ]; }; then
            NIRI_HAS_BLUR=1
        else
            NIRI_HAS_BLUR=0
        fi
    else
        NIRI_VERSION="not installed"
        # We are about to install the distro's current package, which is 26.04+
        # on every supported distro. Keep blur; doctor re-checks after install.
        NIRI_HAS_BLUR=1
    fi
}

detect_noctalia() {
    if have noctalia; then
        NOCTALIA_VERSION="$(noctalia --version 2>/dev/null | head -n1 || true)"
        [ -n "$NOCTALIA_VERSION" ] || NOCTALIA_VERSION="installed"
    else
        NOCTALIA_VERSION="not installed"
    fi
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

preflight() {
    [ "$(uname -s)" = "Linux" ] || die "craft-rice only supports Linux (found $(uname -s))"

    if [ "$(id -u)" = "0" ]; then
        die "Do not run craft-rice as root. Run it as your normal user; it will ask for sudo only for packages."
    fi

    [ -n "${HOME:-}" ] || die "HOME is not set"
    [ -d "$HOME" ] || die "HOME does not point to a directory: $HOME"

    if [ "$HOME" != "$(cd "$HOME" && pwd)" ]; then
        warn "HOME contains a symlink or trailing slash: $HOME"
    fi

    case "$(cr_home)" in
        *' '*)
            warn "Your HOME contains spaces. craft-rice quotes paths, but some upstream tools may not." ;;
    esac

    detect_arch
    detect_distro
    detect_niri
    detect_noctalia

    case "$ARCH" in
        x86_64|amd64|aarch64|arm64) ;;
        *) warn "Untested architecture: $ARCH. The bundled oniri binary is x86_64 and will be skipped." ;;
    esac

    if [ "$DISTRO_FAMILY" = "nixos" ]; then
        warn "NixOS detected. craft-rice writes plain files under \$HOME, which works,"
        warn "but NixOS users normally manage Niri/Noctalia through Home Manager."
        warn "Continue only if you are not using a declarative config for these paths."
        if [ "$FORCE" != "1" ] && ! ask_yes_no "Continue on NixOS anyway?" "n"; then
            exit 1
        fi
    fi

    if [ "$DISTRO_FAMILY" = "unknown" ]; then
        warn "Unrecognised distribution. Package installation will be skipped;"
        warn "you will get the list of packages to install manually."
    fi

    if [ -n "${container:-}" ] || [ -f /.dockerenv ]; then
        warn "Container detected. Niri cannot start here; dotfiles will still install."
    fi
}
