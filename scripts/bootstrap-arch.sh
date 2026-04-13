install_platform_packages() {
  if ! have pacman; then
    record_warning "pacman is not available"
    return 1
  fi

  install_pacman_package git
  install_pacman_package btop
  install_pacman_package curl
  install_pacman_package direnv
  install_pacman_package stow
  install_pacman_package zsh
  install_pacman_package bat
  install_pacman_package fd
  install_pacman_package eza
  install_pacman_package delta
  install_pacman_package jq
  install_pacman_package lazygit
  install_pacman_package neovim
  install_pacman_package ripgrep
  install_pacman_package zoxide
  install_pacman_package starship
  install_pacman_package mise
  install_pacman_package tmux
  install_pacman_package fzf
  install_pacman_package code
  install_pacman_package ghostty
}
