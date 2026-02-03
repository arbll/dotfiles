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
