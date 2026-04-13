install_platform_packages() {
  if ! have apt-get; then
    record_warning "apt-get is not available"
    return 1
  fi

  run_shell "Update apt package index" "$SUDO apt-get update"

  install_apt_package git
  install_apt_package btop
  install_apt_package curl
  install_apt_package direnv
  install_apt_package stow
  install_apt_package zsh
  install_apt_package bat
  install_apt_package fd-find
  install_apt_package eza
  install_apt_package git-delta
  install_apt_package jq
  install_apt_package lazygit
  install_apt_package neovim
  install_apt_package ripgrep
  install_apt_package zoxide
  install_apt_package tmux
  install_apt_package fzf

  if [ "$IS_WSL" -eq 1 ]; then
    record_success "Skipping Linux VS Code install inside WSL"
  else
    install_snap_package code --classic
  fi
  install_snap_package ghostty --classic
  install_apt_package starship || install_starship_fallback
  install_apt_package mise || install_mise_fallback
}
