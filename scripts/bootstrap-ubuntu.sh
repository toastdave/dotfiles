install_platform_packages() {
  if ! have apt-get; then
    record_warning "apt-get is not available"
    return 1
  fi

  run_shell "Update apt package index" "$SUDO apt-get update"

  install_apt_packages "Install Ubuntu bootstrap packages" git curl stow zsh tmux unzip fontconfig
}

install_platform_gui_apps() {
  if [ "$IS_WSL" -eq 1 ]; then
    record_success "Skipping Linux VS Code install inside WSL"
    record_success "Skipping Ghostty install inside WSL"
  else
    install_apt_package snapd
    if have systemctl; then
      run_shell "Enable snapd socket" "$SUDO systemctl enable --now snapd.socket"
    else
      record_warning "systemctl is not available, snapd may need manual startup"
    fi
    if [ ! -e /snap ] && [ -d /var/lib/snapd/snap ]; then
      run_shell "Create /snap symlink" "$SUDO ln -s /var/lib/snapd/snap /snap"
    fi
    install_snap_package code --classic
    install_snap_package ghostty --classic
  fi
}
