# Fall back to xterm-256color if the terminal type is unknown
if not test -e /usr/share/terminfo/(string sub -l 1 $TERM)/$TERM
    set -gx TERM xterm-256color
end

set -gx SHELL fish
set -gx EDITOR hx
set -gx PAGER less
set -gx MANPAGER 'less'

# Datadog-specific environment variables
if test -d "$HOME/dd"
    # Hack to fix formatting issues in integration-core
    set -gx HATCH_PYTHON python3.13
end

fish_add_path -g "$HOME/.local/bin"
fish_add_path -g "$HOME/.local/go/bin"
