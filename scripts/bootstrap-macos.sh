#!/usr/bin/env bash
install_platform_packages() {
  if ! have brew; then
    record_warning "Homebrew is not installed"
    return 1
  fi

  run_cmd "Install macOS Homebrew essentials" brew bundle install --no-upgrade --file="$DOTFILES_DIR/macos/Brewfile.core"
}

install_platform_gui_apps() {
  install_brew_cask ghostty

  if brew list --cask visual-studio-code >/dev/null 2>&1; then
    record_success "visual-studio-code already installed via Homebrew cask"
  elif [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ]; then
    record_success "Visual Studio Code.app already exists"
  else
    install_brew_cask visual-studio-code
  fi
}
