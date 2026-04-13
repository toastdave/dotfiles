install_platform_packages() {
  if ! have brew; then
    record_warning "Homebrew is not installed"
    return 1
  fi

  install_brew_formula git
  install_brew_formula btop
  install_brew_formula curl
  install_brew_formula direnv
  install_brew_formula stow
  install_brew_formula zsh
  install_brew_formula bat
  install_brew_formula fd
  install_brew_formula eza
  install_brew_formula git-delta
  install_brew_formula jq
  install_brew_formula lazygit
  install_brew_formula neovim
  install_brew_formula ripgrep
  install_brew_formula zoxide
  install_brew_formula starship
  install_brew_formula mise
  install_brew_formula tmux
  install_brew_formula fzf
  install_brew_cask ghostty
  install_brew_cask visual-studio-code
}
