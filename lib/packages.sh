# shellcheck shell=bash
# craft-rice — package detection and installation

REQUIRED_PKGS=(
    niri kitty noctalia xwayland-satellite polkit-agent
    playerctl brightnessctl wl-clipboard
    fontconfig gtk3 adwaita-icons breeze-icons
    pipewire wireplumber networkmanager bluez
    xdg-portal xdg-portal-gtk mesa
    starship fastfetch
)

OPTIONAL_PKGS=(grim slurp btop zoxide fzf eza bat)

# Logical name -> distro package name. Empty means "no known package"; the
# installer then prints a manual instruction instead of calling the package
# manager with a name that cannot exist.
pkg_name() {
    local logical="$1"
    case "$logical" in
        niri)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'gui-wm/niri\n' ;;
                *)      printf 'niri\n' ;;
            esac ;;
        kitty)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'x11-terms/kitty\n' ;;
                *)      printf 'kitty\n' ;;
            esac ;;
        xwayland-satellite)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'gui-apps/xwayland-satellite\n' ;;
                *)      printf 'xwayland-satellite\n' ;;
            esac ;;
        playerctl)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'media-sound/playerctl\n' ;;
                *)      printf 'playerctl\n' ;;
            esac ;;
        brightnessctl)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'app-misc/brightnessctl\n' ;;
                *)      printf 'brightnessctl\n' ;;
            esac ;;
        wl-clipboard)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'gui-apps/wl-clipboard\n' ;;
                *)      printf 'wl-clipboard\n' ;;
            esac ;;
        fontconfig)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'media-libs/fontconfig\n' ;;
                *)      printf 'fontconfig\n' ;;
            esac ;;
        pipewire)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'media-video/pipewire\n' ;;
                *)      printf 'pipewire\n' ;;
            esac ;;
        wireplumber)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'media-video/wireplumber\n' ;;
                *)      printf 'wireplumber\n' ;;
            esac ;;
        networkmanager)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'net-misc/networkmanager\n' ;;
                *)      printf 'NetworkManager\n' ;;
            esac ;;
        bluez)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'net-wireless/bluez\n' ;;
                *)      printf 'bluez\n' ;;
            esac ;;
        xdg-portal)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'sys-apps/xdg-desktop-portal\n' ;;
                *)      printf 'xdg-desktop-portal\n' ;;
            esac ;;
        xdg-portal-gtk)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'gui-libs/xdg-desktop-portal-gtk\n' ;;
                *)      printf 'xdg-desktop-portal-gtk\n' ;;
            esac ;;
        mesa)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'media-libs/mesa\n' ;;
                *)      printf 'mesa\n' ;;
            esac ;;
        starship)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'app-shells/starship\n' ;;
                *)      printf 'starship\n' ;;
            esac ;;
        fastfetch)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'app-misc/fastfetch\n' ;;
                *)      printf 'fastfetch\n' ;;
            esac ;;
        grim)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'gui-apps/grim\n' ;;
                *)      printf 'grim\n' ;;
            esac ;;
        slurp)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'gui-apps/slurp\n' ;;
                *)      printf 'slurp\n' ;;
            esac ;;
        btop)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'sys-process/btop\n' ;;
                *)      printf 'btop\n' ;;
            esac ;;
        zoxide)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'app-shells/zoxide\n' ;;
                *)      printf 'zoxide\n' ;;
            esac ;;
        fzf)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'app-shells/fzf\n' ;;
                *)      printf 'fzf\n' ;;
            esac ;;

        noctalia)
            case "$DISTRO_FAMILY" in
                arch|fedora|opensuse|solus|void) printf 'noctalia\n' ;;
                *) printf '\n' ;;
            esac ;;
        polkit-agent)
            case "$DISTRO_FAMILY" in
                arch)    printf 'lxqt-policykit\n' ;;
                debian)  printf 'lxqt-policykit\n' ;;
                gentoo)  printf 'gnome-extra/polkit-gnome\n' ;;
                fedora|opensuse|void|alpine|solus) printf 'polkit-gnome\n' ;;
                *) printf '\n' ;;
            esac ;;
        gtk3)
            case "$DISTRO_FAMILY" in
                debian) printf 'libgtk-3-0\n' ;;
                void)   printf 'gtk+3\n' ;;
                alpine) printf 'gtk+3.0\n' ;;
                gentoo) printf 'x11-libs/gtk+:3\n' ;;
                solus)  printf 'libgtk-3\n' ;;
                *)      printf 'gtk3\n' ;;
            esac ;;
        adwaita-icons)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'x11-themes/adwaita-icon-theme\n' ;;
                *)      printf 'adwaita-icon-theme\n' ;;
            esac ;;
        breeze-icons)
            case "$DISTRO_FAMILY" in
                debian)  printf 'breeze-icon-theme\n' ;;
                fedora)  printf 'breeze-icon-theme\n' ;;
                opensuse) printf 'breeze5-icons\n' ;;
                gentoo)  printf 'kde-frameworks/breeze-icons\n' ;;
                *)       printf 'breeze-icons\n' ;;
            esac ;;
        eza)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'sys-apps/eza\n' ;;
                *)      printf 'eza\n' ;;
            esac ;;
        bat)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'sys-apps/bat\n' ;;
                *)      printf 'bat\n' ;;
            esac ;;
        fish)
            case "$DISTRO_FAMILY" in
                gentoo) printf 'app-shells/fish\n' ;;
                *)      printf 'fish\n' ;;
            esac ;;
        zsh|bash) printf '%s\n' "$logical" ;;
        *) printf '%s\n' "$logical" ;;
    esac
}

# Is a package installed? Uses the package manager, then falls back to PATH.
pkg_installed() {
    local name="$1"
    [ -n "$name" ] || return 1

    case "$PKG_MANAGER" in
        pacman) pacman -Qq -- "$name" >/dev/null 2>&1 ;;
        dnf)    rpm -q -- "$name" >/dev/null 2>&1 ;;
        apt)    dpkg-query -W -f='${Status}' -- "$name" 2>/dev/null | grep -q 'install ok installed' ;;
        zypper) rpm -q -- "$name" >/dev/null 2>&1 || zypper --non-interactive se -i --match-exact -- "$name" >/dev/null 2>&1 ;;
        xbps)   xbps-query -- "$name" >/dev/null 2>&1 ;;
        apk)    apk info -e -- "$name" >/dev/null 2>&1 ;;
        emerge)
            if have portageq; then
                portageq has_version / "$name" >/dev/null 2>&1
            else
                emerge --quiet --pretend -- "$name" 2>/dev/null | grep -q 'ebuild'
                [ "$?" -ne 0 ]
            fi ;;
        eopkg)  eopkg list-installed 2>/dev/null | grep -q "^${name} " ;;
        *)      have "$name" ;;
    esac
}

# Is the logical feature already usable?
feature_present() {
    local logical="$1"
    case "$logical" in
        niri)               have niri ;;
        kitty)              have kitty ;;
        noctalia)           have noctalia ;;
        xwayland-satellite) have xwayland-satellite ;;
        polkit-agent)       have lxqt-policykit-agent \
                            || have polkit-gnome-authentication-agent-1 \
                            || have hyprpolkitagent \
                            || [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ] ;;
        playerctl)          have playerctl ;;
        brightnessctl)      have brightnessctl ;;
        wl-clipboard)       have wl-copy ;;
        fontconfig)         have fc-cache ;;
        gtk3)               pkg_installed "$(pkg_name gtk3)" ;;
        adwaita-icons)      [ -d /usr/share/icons/Adwaita ] || [ -d /usr/share/icons/adwaita ] ;;
        breeze-icons)       [ -d /usr/share/icons/breeze-dark ] || [ -d /usr/share/icons/breeze ] ;;
        pipewire)           have pipewire ;;
        wireplumber)        have wireplumber ;;
        networkmanager)     have NetworkManager || have nmcli ;;
        bluez)              have bluetoothctl ;;
        xdg-portal)         pkg_installed "$(pkg_name xdg-portal)" ;;
        xdg-portal-gtk)     pkg_installed "$(pkg_name xdg-portal-gtk)" ;;
        mesa)               pkg_installed "$(pkg_name mesa)" ;;
        starship)           have starship ;;
        fastfetch)          have fastfetch ;;
        grim)               have grim ;;
        slurp)              have slurp ;;
        btop)               have btop ;;
        zoxide)             have zoxide ;;
        fzf)                have fzf ;;
        eza)                have eza ;;
        bat)                have bat || have batcat ;;
        fish|zsh|bash)      have "$logical" ;;
        *)                  pkg_installed "$(pkg_name "$logical")" ;;
    esac
}

# Build the missing lists. Sets MISSING_REQUIRED and MISSING_OPTIONAL.
# Entries are "logical|package"; package is empty when the distribution has no
# known name, which means "tell the user to install it by hand".
scan_packages() {
    MISSING_REQUIRED=()
    MISSING_OPTIONAL=()
    local logical name

    for logical in "${REQUIRED_PKGS[@]}" "$SHELL_NAME"; do
        feature_present "$logical" && continue
        name="$(pkg_name "$logical")"
        MISSING_REQUIRED+=("$logical|$name")
    done

    for logical in "${OPTIONAL_PKGS[@]}"; do
        feature_present "$logical" && continue
        name="$(pkg_name "$logical")"
        MISSING_OPTIONAL+=("$logical|$name")
    done
}

# Entries from MISSING_REQUIRED that actually have a package name.
installable_missing() {
    local entry
    for entry in "${MISSING_REQUIRED[@]+"${MISSING_REQUIRED[@]}"}"; do
        [ -n "${entry#*|}" ] && printf '%s\n' "$entry"
    done
}

print_package_table() {
    local entry logical name status
    section "Package scan — $(distro_summary)"
    printf '  %-20s %-32s %s\n' "FEATURE" "PACKAGE" "STATUS"

    for logical in "${REQUIRED_PKGS[@]}" "$SHELL_NAME"; do
        name="$(pkg_name "$logical")"
        [ -n "$name" ] || name="(manual)"
        if feature_present "$logical"; then
            status="${C_GREEN}installed${C_RESET}"
        else
            status="${C_YELLOW}missing${C_RESET}"
        fi
        printf '  %-20s %-32s %b\n' "$logical" "$name" "$status"
    done

    if [ "${#MISSING_OPTIONAL[@]}" -gt 0 ]; then
        printf '\n  %soptional (not installed automatically)%s\n' "$C_DIM" "$C_RESET"
        for entry in "${MISSING_OPTIONAL[@]}"; do
            logical="${entry%%|*}"
            name="${entry#*|}"
            [ -n "$name" ] || name="(manual)"
            printf '  %-20s %-32s %b\n' "$logical" "$name" "${C_DIM}missing${C_RESET}"
        done
    fi
    printf '\n'
}

manual_package_hint() {
    local logical="$1"
    case "$logical" in
        noctalia)
            case "$DISTRO_FAMILY" in
                debian)
                    cat <<'EOF'
  Noctalia on Debian/Ubuntu uses the official APT repository:
    https://docs.noctalia.dev/noctalia/getting-started/installation/
  Follow the "Debian (including Ubuntu)" section, then re-run:
    craft-rice install --no-packages
EOF
                    ;;
                *)
                    cat <<'EOF'
  Noctalia is not packaged for this distribution. Install it manually:
    https://docs.noctalia.dev/noctalia/getting-started/installation/
  Then re-run:
    craft-rice install --no-packages
EOF
                    ;;
            esac ;;
        *)
            printf '  Install %s with your package manager, then re-run with --no-packages.\n' "$logical" ;;
    esac
}

install_missing_packages() {
    [ "$NO_PACKAGES" = "1" ] && { info "Skipping package installation (--no-packages)"; return 0; }
    [ "${#MISSING_REQUIRED[@]}" -eq 0 ] && { ok "All required packages are already installed"; return 0; }

    local entry
    local -a manual=()
    for entry in "${MISSING_REQUIRED[@]}"; do
        [ -n "${entry#*|}" ] || manual+=("${entry%%|*}")
    done

    # Packages the distribution cannot provide get a hint, never an install.
    for entry in "${manual[@]+"${manual[@]}"}"; do
        warn "No package name known for: $entry"
        manual_package_hint "$entry"
    done

    local -a installable=()
    mapfile -t installable < <(installable_missing)
    if [ "${#installable[@]}" -eq 0 ]; then
        warn "Nothing installable automatically. Install the packages above, then re-run with --no-packages."
        return 0
    fi

    if [ -z "$PKG_INSTALL_CMD" ]; then
        warn "No supported package manager found. Install these manually:"
        for entry in "${installable[@]}"; do
            printf '  - %s (%s)\n' "${entry%%|*}" "${entry#*|}"
        done
        return 0
    fi

    local names=()
    for entry in "${installable[@]}"; do
        names+=("${entry#*|}")
    done

    log "Missing: ${names[*]}"
    log "Command: ${PKG_INSTALL_CMD} ${names[*]}"

    if ! ask_yes_no "Install these packages now? (needs sudo)" "y"; then
        warn "Skipped. craft-rice will still install the dotfiles."
        for entry in "${installable[@]}"; do
            manual_package_hint "${entry%%|*}"
        done
        return 0
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s %s %s\n' "$C_DIM" "$C_RESET" "$PKG_INSTALL_CMD" "${names[*]}"
        return 0
    fi

    [ -n "$PKG_UPDATE_CMD" ] && run_shell "$PKG_UPDATE_CMD" || true

    # Try everything at once first; fall back to one-by-one so a single bad
    # package name does not block the rest.
    if ! run_shell "$PKG_INSTALL_CMD ${names[*]}"; then
        warn "Batch install failed. Retrying one package at a time..."
        local name
        for name in "${names[@]}"; do
            run_shell "$PKG_INSTALL_CMD $name" || warn "Could not install: $name"
        done
    fi
}

# Re-detect after installation so the rest of the run sees the new tools.
refresh_detection() {
    detect_niri
    detect_noctalia
    hash -r 2>/dev/null || true
}
