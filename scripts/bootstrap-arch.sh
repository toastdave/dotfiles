install_platform_packages() {
  if ! have pacman; then
    record_warning "pacman is not available"
    return 1
  fi

  install_pacman_packages "Install Arch core packages" git btop curl direnv stow zsh bat fd jq neovim ripgrep tmux fzf
  install_pacman_package eza
  install_pacman_package delta
  install_pacman_package lazygit
  install_pacman_package zoxide
  install_pacman_package starship
  install_pacman_package mise
  install_pacman_package code
  install_pacman_package ghostty
}
