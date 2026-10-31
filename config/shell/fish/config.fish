# craft-rice — Fish configuration
#
# Only the essentials: prompt, navigation, history, and the rice aliases.
# Every optional program is guarded, so a minimal install still gives you a
# working shell.

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

fish_add_path ~/.local/bin ~/.cargo/bin

if test -f ~/.fish_profile
    source ~/.fish_profile
end

# ---------------------------------------------------------------------------
# Greeting
# ---------------------------------------------------------------------------

function fish_greeting
    if type -q fastfetch
        fastfetch
    end
end

# ---------------------------------------------------------------------------
# Man pages
# ---------------------------------------------------------------------------

if type -q bat
    set -gx MANROFFOPT -c
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

# ---------------------------------------------------------------------------
# Interactive only
# ---------------------------------------------------------------------------

if status is-interactive
    fish_vi_key_bindings

    set fish_cursor_default block
    set fish_cursor_insert line
    set fish_cursor_replace_one underscore
    set fish_cursor_visual block

    # !! — previous command
    function __history_previous_command
        switch (commandline -t)
            case "!"
                commandline -t $history[1]
                commandline -f repaint
            case "*"
                commandline -i !
        end
    end

    # !$ — previous command arguments
    function __history_previous_command_arguments
        switch (commandline -t)
            case "!"
                commandline -t ""
                commandline -f history-token-search-backward
            case "*"
                commandline -i '$'
        end
    end

    bind -Minsert ! __history_previous_command
    bind -Minsert '$' __history_previous_command_arguments
end

# ---------------------------------------------------------------------------
# Navigation and listing
# ---------------------------------------------------------------------------

if type -q eza
    alias ls='eza --color=always --group-directories-first --icons=always'
    alias la='eza -a --color=always --group-directories-first --icons=always'
    alias ll='eza -l --color=always --group-directories-first --icons=always'
    alias lt='eza -aT --color=always --group-directories-first --icons=always'
    alias l.="eza -a | grep -e '^\.'"
end

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

if type -q grep
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
end

# ---------------------------------------------------------------------------
# Optional integrations (silently skipped when not installed)
# ---------------------------------------------------------------------------

if type -q zoxide
    zoxide init fish --cmd cd | source
end

if type -q fzf
    set -gx FZF_CTRL_R_OPTS "--with-nth 3.."
    fzf --fish | source
    set -g fzf_history_opts --no-preview
    set -g fzf_preview_file_cmd "fish -c"
    set -g fzf_history_time_format "%H:%M "
end

if status is-interactive; and type -q starship
    starship init fish | source
end
