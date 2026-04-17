install_platform_packages() {
  if ! have pacman; then
    record_warning "pacman is not available"
    return 1
  fi

  install_pacman_packages "Install Arch bootstrap packages" git curl stow zsh tmux
}

install_platform_gui_apps() {
  if [ "$IS_WSL" -eq 1 ]; then
    record_success "Skipping Linux VS Code install inside WSL"
    record_success "Skipping Ghostty install inside WSL"
    return 0
  fi

  install_pacman_package code
  install_pacman_package ghostty
}
