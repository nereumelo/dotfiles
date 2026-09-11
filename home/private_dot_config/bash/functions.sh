# ~/.config/bash/functions.sh — anything with args/conditionals

mkcd() {
  mkdir -p -- "$1" && cd -- "$1" || return
}
