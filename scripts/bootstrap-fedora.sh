install_platform_packages() {
  if ! have dnf; then
    record_warning "dnf is not available"
    return 1
  fi

  run_shell "Refresh dnf metadata" "$SUDO dnf makecache"

  install_dnf_packages "Install Fedora bootstrap packages" git curl stow zsh tmux unzip fontconfig
}

install_platform_gui_apps() {
  if [ "$IS_WSL" -eq 1 ]; then
    record_success "Skipping Linux VS Code install inside WSL"
    record_success "Skipping Ghostty install inside WSL"
    return 0
  fi

  run_shell "Install VS Code RPM repository" "$SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc && printf '%s\\n' '[code]' 'name=Visual Studio Code' 'baseurl=https://packages.microsoft.com/yumrepos/vscode' 'enabled=1' 'autorefresh=1' 'type=rpm-md' 'gpgcheck=1' 'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' | $SUDO tee /etc/yum.repos.d/vscode.repo >/dev/null"
  install_dnf_package code
  run_shell "Install Ghostty Fedora repository" ". /etc/os-release && curl -fsSL \"https://copr.fedorainfracloud.org/coprs/scottames/ghostty/repo/fedora-${VERSION_ID}/scottames-ghostty-fedora-${VERSION_ID}.repo\" | $SUDO tee /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:scottames:ghostty.repo >/dev/null"
  install_dnf_package ghostty
}
