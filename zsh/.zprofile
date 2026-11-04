# Homebrew uses different prefixes on Apple Silicon and Intel Macs.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Login shells used by editors and automation need the same tool selection.
# Interactive shells additionally enable mise activation in .zshrc.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh --shims)"
fi
