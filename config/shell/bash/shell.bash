# craft-rice — Bash integration
#
# Sourced from a marked block in ~/.bashrc. Everything is guarded, so a missing
# optional program never breaks the shell.

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
case ":$PATH:" in
    *":$HOME/.cargo/bin:"*) ;;
    *) PATH="$HOME/.cargo/bin:$PATH" ;;
esac
export PATH

# ---------------------------------------------------------------------------
# Interactive only
# ---------------------------------------------------------------------------

if [[ $- == *i* ]]; then

    set -o vi
    shopt -s checkwinsize 2>/dev/null || true

    # Greeting (once per shell)
    if [[ -z ${CRAFT_RICE_GREETED:-} ]] && command -v fastfetch >/dev/null 2>&1; then
        export CRAFT_RICE_GREETED=1
        fastfetch
    fi

    # Man pages
    if command -v bat >/dev/null 2>&1; then
        export MANROFFOPT=-c
        export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    fi

    # Navigation and listing
    if command -v eza >/dev/null 2>&1; then
        alias ls='eza --color=always --group-directories-first --icons=always'
        alias la='eza -a --color=always --group-directories-first --icons=always'
        alias ll='eza -l --color=always --group-directories-first --icons=always'
        alias lt='eza -aT --color=always --group-directories-first --icons=always'
        alias l.="eza -a | grep -e '^\.'"
    fi

    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias .....='cd ../../../..'
    alias ......='cd ../../../../..'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'

    # Optional integrations
    if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init bash --cmd cd)"
    fi

    if command -v fzf >/dev/null 2>&1; then
        eval "$(fzf --bash 2>/dev/null)"
    fi

    if command -v starship >/dev/null 2>&1; then
        eval "$(starship init bash)"
    fi
fi
