export PATH="$HOME/.local/bin:$PATH"

# Respect an explicitly configured SDK; use the platform convention otherwise.
if [[ "$OSTYPE" == darwin* ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [[ -z "${JAVA_HOME:-}" && -d /Applications/Android\ Studio.app/Contents/jbr/Contents/Home ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  fi
else
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
fi
export ANDROID_SDK_ROOT="$ANDROID_HOME"
if [[ -d "$ANDROID_HOME" ]]; then
  path+=("$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator" "$ANDROID_HOME/cmdline-tools/latest/bin")
fi

# User PATH additions go above activation, so mise tools take precedence.
if command -v mise >/dev/null 2>&1; then
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
  # Only route cd through zoxide in interactive shells. Non-interactive shells
  # (editor tasks, tooling, `zsh -lc`) have no zoxide chpwd hook installed, so a
  # cd=z alias there makes every cd trip zoxide's "configuration issue" warning.
  [[ -o interactive ]] && alias cd='z'
fi

if command -v claude >/dev/null 2>&1; then
  alias yolo='claude --dangerously-skip-permissions'
fi

alias gw='git worktree'

export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

if [[ "$TERM" != dumb ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Docker / Colima completions
[[ -d "$HOME/.zsh/completions" ]] && fpath=("$HOME/.zsh/completions" $fpath)
autoload -Uz compinit && compinit

# zoxide: initialize LAST (after compinit) so its chpwd hook is appended last and
# its `z`/`cd` tab-completion registers — `compdef` only exists after compinit.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi


[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
