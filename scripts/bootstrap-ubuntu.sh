install_platform_packages() {
  if ! have apt-get; then
    record_warning "apt-get is not available"
    return 1
  fi

  run_shell "Update apt package index" "$SUDO apt-get update"

  install_apt_packages "Install Ubuntu core packages" git btop curl direnv stow zsh bat fd-find jq neovim ripgrep tmux fzf
  install_apt_package eza
  install_apt_package git-delta
  install_apt_package lazygit
  install_apt_package zoxide

  if [ "$IS_WSL" -eq 1 ]; then
    record_success "Skipping Linux VS Code install inside WSL"
  else
    install_snap_package code --classic
  fi
  install_snap_package ghostty --classic
  install_apt_package starship || install_starship_fallback
  install_apt_package mise || install_mise_fallback
}
