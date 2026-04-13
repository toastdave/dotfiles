install_platform_packages() {
  if ! have dnf; then
    record_warning "dnf is not available"
    return 1
  fi

  run_shell "Refresh dnf metadata" "$SUDO dnf makecache"

  install_dnf_package git
  install_dnf_package btop
  install_dnf_package curl
  install_dnf_package direnv
  install_dnf_package stow
  install_dnf_package zsh
  install_dnf_package bat
  install_dnf_package fd-find
  install_dnf_package eza
  install_dnf_package git-delta
  install_dnf_package jq
  install_dnf_package lazygit
  install_dnf_package neovim
  install_dnf_package ripgrep
  install_dnf_package zoxide
  install_dnf_package starship
  install_dnf_package mise || install_mise_fallback
  install_dnf_package tmux
  install_dnf_package fzf
  install_dnf_package code
  install_dnf_package ghostty
}
