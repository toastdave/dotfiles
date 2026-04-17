export PATH="$HOME/.local/bin:$PATH"

if [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
elif [ -x "/usr/local/bin/mise" ]; then
  eval "$("/usr/local/bin/mise" activate zsh)"
elif [ -x "/opt/homebrew/bin/mise" ]; then
  eval "$("/opt/homebrew/bin/mise" activate zsh)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --all --long --group-directories-first --icons --header --time-style long-iso'
fi

if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi

if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi

if command -v zoxide >/dev/null 2>&1; then
  alias cd='z'
fi

alias gw='git worktree'

export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
