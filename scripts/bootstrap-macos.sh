install_platform_packages() {
  if ! have brew; then
    record_warning "Homebrew is not installed"
    return 1
  fi

  install_brew_formulas "Install macOS Homebrew bootstrap formulas" git curl stow zsh tmux
}

install_platform_gui_apps() {
  install_brew_cask ghostty
  install_brew_cask visual-studio-code
}
