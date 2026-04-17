install_platform_packages() {
  if ! have dnf; then
    record_warning "dnf is not available"
    return 1
  fi

  run_shell "Refresh dnf metadata" "$SUDO dnf makecache"

  install_dnf_packages "Install Fedora core packages" git btop curl direnv stow zsh bat fd-find jq neovim ripgrep tmux fzf
  install_dnf_package eza
  install_dnf_package git-delta
  install_dnf_package lazygit
  install_dnf_package zoxide
  install_dnf_package starship
  install_dnf_package mise || install_mise_fallback
  install_dnf_package code
  install_dnf_package ghostty
}
