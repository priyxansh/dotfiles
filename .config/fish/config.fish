function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive # Commands to run in interactive sessions can go here

    # No greeting
    set fish_greeting

    # Use starship
    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear properly
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias ls 'eza --icons'
    alias pamcan pacman
    alias q 'qs -c ii'
    alias normalmode="pw-metadata -n settings 0 clock.force-quantum 512"
    alias shredmode="pw-metadata -n settings 0 clock.force-quantum 128"    
end

#ASCII cinnamoroll
fastfetch

#PATH rm
set -gx PATH $HOME/.local/bin $PATH

function set-quantum
    if test -n "$argv[1]"
        pw-metadata -n settings 0 clock.force-quantum $argv[1]
        echo "Quantum set to: $argv[1]"
    else
        echo "Please provide a value (e.g., set-quantum 64)"
    end
end
