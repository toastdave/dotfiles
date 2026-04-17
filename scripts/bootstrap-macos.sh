install_platform_packages() {
  if ! have brew; then
    record_warning "Homebrew is not installed"
    return 1
  fi

  install_brew_formulas "Install macOS Homebrew formulas" git btop curl direnv stow zsh bat fd eza git-delta jq lazygit neovim ripgrep zoxide starship mise tmux fzf
  install_brew_cask ghostty
  install_brew_cask visual-studio-code
}
