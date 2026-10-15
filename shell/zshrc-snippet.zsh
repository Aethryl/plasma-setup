if [[ -o interactive && -t 1 && -z "$ZED_TERM" && ! -e "$XDG_RUNTIME_DIR/fastfetch-shown" ]]; then
  command -v fastfetch &>/dev/null && fastfetch
  touch "$XDG_RUNTIME_DIR/fastfetch-shown"
fi

command -v starship &>/dev/null && eval "$(starship init zsh)"
