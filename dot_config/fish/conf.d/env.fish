set -gx SHELL fish
set -gx EDITOR nvim
set -gx PAGER less
set -gx MANPAGER 'nvim +Man!'

fish_add_path -g "$HOME/.local/bin"
fish_add_path -g "$HOME/.local/go/bin"
