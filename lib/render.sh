# shellcheck shell=bash
# craft-rice — template rendering

WALLPAPER_DIR=""
WALLPAPER_DEFAULT=""

# cr_render SRC DST
cr_render() {
    local src="$1" dst="$2" content
    [ -r "$src" ] || die "Template not found: $src"
    content="$(<"$src")"

    content="${content//@HOME@/$HOME}"
    content="${content//@XDG_CONFIG_HOME@/$(cr_config_home)}"
    content="${content//@XDG_DATA_HOME@/$(cr_data_home)}"
    content="${content//@XDG_STATE_HOME@/$(cr_state_home)}"
    content="${content//@XDG_CACHE_HOME@/$(cr_cache_home)}"
    content="${content//@WALLPAPER_DIR@/$WALLPAPER_DIR}"
    content="${content//@WALLPAPER_DEFAULT@/$WALLPAPER_DEFAULT}"
    content="${content//@SHELL@/$SHELL_NAME}"
    content="${content//@DISTRO@/${DISTRO_ID:-linux}}"

    printf '%s\n' "$content" >"$dst"
}

# cr_strip_blur SRC DST — remove blocks wrapped in craft-rice:blur markers.
cr_strip_blur() {
    local src="$1" dst="$2"
    awk '
        /^[[:space:]]*\/\/ craft-rice:blur-begin/ { skip = 1; next }
        /^[[:space:]]*\/\/ craft-rice:blur-end/   { skip = 0; next }
        !skip { print }
    ' "$src" >"$dst"
}

# cr_render_niri DST — render config.kdl with or without blur.
cr_render_niri() {
    local dst="$1" tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/craft-rice-niri.XXXXXX")"
    if [ "$NIRI_HAS_BLUR" = "1" ]; then
        cr_render "$CR_ROOT/config/niri/config.kdl.tmpl" "$tmp"
    else
        cr_strip_blur "$CR_ROOT/config/niri/config.kdl.tmpl" "$tmp"
        cr_render "$tmp" "$tmp.rendered"
        mv -f -- "$tmp.rendered" "$tmp"
    fi
    mv -f -- "$tmp" "$dst"
}

# cr_generate_outputs DST — snapshot the running Niri layout, or write the
# comment-only default.
cr_generate_outputs() {
    local dst="$1" json
    json="$(mktemp "${TMPDIR:-/tmp}/craft-rice-outputs.XXXXXX.json")"

    if have niri && have python3 && niri msg --json outputs >"$json" 2>/dev/null; then
        if python3 "$CR_ROOT/lib/outputs.py" <"$json" >"$dst" 2>/dev/null && [ -s "$dst" ]; then
            rm -f -- "$json"
            ok "Monitor layout captured from the running Niri session"
            return 0
        fi
    fi

    rm -f -- "$json"
    cp -- "$CR_ROOT/config/niri/outputs.kdl" "$dst"
    debug "No running Niri session; using auto-detect outputs"
    return 0
}
