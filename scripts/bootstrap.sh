#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DOTFILES_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
IS_WSL=0

export PATH="$HOME/.local/bin:$PATH"

SUCCESS_ITEMS=()
WARNING_ITEMS=()
FAILED_ITEMS=()

PACKAGES=(zsh starship mise ghostty opencode tmux)

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

log() {
  printf '%s\n' "$1"
}

record_success() {
  SUCCESS_ITEMS+=("$1")
  log "[ok] $1"
}

record_warning() {
  WARNING_ITEMS+=("$1")
  log "[warn] $1"
}

record_failure() {
  FAILED_ITEMS+=("$1")
  log "[fail] $1"
}

run_cmd() {
  local label=$1
  shift

  if "$@"; then
    record_success "$label"
    return 0
  fi

  record_warning "$label"
  return 1
}

run_shell() {
  local label=$1
  local command=$2

  if bash -lc "$command"; then
    record_success "$label"
    return 0
  fi

  record_warning "$label"
  return 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

install_brew_formula() {
  local package=$1
  if brew list --formula "$package" >/dev/null 2>&1; then
    record_success "$package already installed via Homebrew"
    return 0
  fi
  run_shell "Install $package with Homebrew" "brew install $package"
}

install_brew_cask() {
  local package=$1
  if brew list --cask "$package" >/dev/null 2>&1; then
    record_success "$package already installed via Homebrew cask"
    return 0
  fi
  run_shell "Install $package with Homebrew cask" "brew install --cask $package"
}

install_apt_package() {
  local package=$1
  run_shell "Install $package with apt" "$SUDO apt-get install -y $package"
}

install_pacman_package() {
  local package=$1
  run_shell "Install $package with pacman" "$SUDO pacman -S --noconfirm --needed $package"
}

install_snap_package() {
  local package=$1
  local flags=${2:-}

  if ! have snap; then
    record_warning "snap is not available, skipping $package"
    return 1
  fi

  if snap list "$package" >/dev/null 2>&1; then
    record_success "$package already installed via snap"
    return 0
  fi

  run_shell "Install $package with snap" "$SUDO snap install $package $flags"
}

install_starship_fallback() {
  if have starship; then
    record_success "starship already available"
    return 0
  fi
  run_shell "Install starship with upstream script" "curl -fsSL https://starship.rs/install.sh | sh -s -- -y"
}

install_mise_fallback() {
  if have mise; then
    record_success "mise already available"
    return 0
  fi
  run_shell "Install mise with upstream script" "curl -fsSL https://mise.run | sh"
}

install_opencode_fallback() {
  if have opencode; then
    record_success "opencode already available"
    return 0
  fi
  run_shell "Install opencode with upstream script" "curl -fsSL https://opencode.ai/install | bash"
}

set_git_default_branch() {
  if ! have git; then
    record_warning "git is not available, skipping default branch setup"
    return 1
  fi

  run_shell "Set git default branch to main" "git config --global init.defaultBranch main"
}

install_tpm() {
  local target="$TMUX_PLUGIN_MANAGER_PATH/tpm"
  run_shell "Create tmux plugin directory" "mkdir -p \"$TMUX_PLUGIN_MANAGER_PATH\""
  if [ -d "$target" ]; then
    record_success "tmux plugin manager already present"
    return 0
  fi
  run_shell "Install tmux plugin manager" "git clone https://github.com/tmux-plugins/tpm \"$target\""
}

install_tmux_plugins() {
  local tpm_bin="$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins"
  local tmux_conf="$HOME/.config/tmux/tmux.conf"

  if [ ! -x "$tpm_bin" ]; then
    record_warning "tmux plugin manager install script is unavailable"
    return 1
  fi

  if [ ! -f "$tmux_conf" ]; then
    record_warning "tmux config not found at $tmux_conf"
    return 1
  fi

  run_shell "Prime tmux plugin manager path" "tmux start-server \; source-file \"$tmux_conf\" \; set-environment -g TMUX_PLUGIN_MANAGER_PATH \"$TMUX_PLUGIN_MANAGER_PATH\""

  run_shell "Install tmux plugins" "TMUX_PLUGIN_MANAGER_PATH=\"$TMUX_PLUGIN_MANAGER_PATH\" \"$tpm_bin\""
}

set_default_shell_to_zsh() {
  local zsh_path

  if ! have zsh; then
    record_warning "zsh not installed yet, skipping default shell change"
    return 1
  fi

  zsh_path=$(command -v zsh)

  if [ "${SHELL:-}" = "$zsh_path" ]; then
    record_success "zsh already set as default shell"
    return 0
  fi

  if ! have chsh; then
    record_warning "chsh not available, skipping default shell change"
    return 1
  fi

  if [ -r /etc/shells ] && ! grep -qx "$zsh_path" /etc/shells; then
    record_warning "$zsh_path is not listed in /etc/shells"
    return 1
  fi

  run_shell "Set zsh as default shell" "chsh -s \"$zsh_path\" \"$USER\""
}

stow_packages() {
  local package
  for package in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$package" ]; then
      run_shell "Stow $package" "cd \"$DOTFILES_DIR\" && stow --target=\"$HOME\" --restow $package"
    else
      record_warning "Missing stow package: $package"
    fi
  done
}

run_mise_install() {
  if ! have mise; then
    record_warning "mise not available, skipping runtime install"
    return 1
  fi
  run_shell "Install runtimes with mise" "mise install"
}

report_path_setup() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*)
      record_success "~/.local/bin already on PATH"
      ;;
    *)
      record_warning "~/.local/bin is not on PATH; add it if fallback installers use it"
      ;;
  esac
}

detect_platform() {
  local uname_out
  uname_out=$(uname -s)

  if [ "$uname_out" = "Darwin" ]; then
    TARGET_SCRIPT="$SCRIPT_DIR/bootstrap-macos.sh"
    return 0
  fi

  if [ "$uname_out" = "Linux" ]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
      IS_WSL=1
      record_success "Running inside WSL"
    fi

    if [ -r /etc/os-release ]; then
      . /etc/os-release
      case "${ID:-}" in
        ubuntu|debian)
          TARGET_SCRIPT="$SCRIPT_DIR/bootstrap-ubuntu.sh"
          return 0
          ;;
        arch)
          TARGET_SCRIPT="$SCRIPT_DIR/bootstrap-arch.sh"
          return 0
          ;;
      esac
    fi
  fi

  TARGET_SCRIPT=""
  return 1
}

main() {
  if ! detect_platform; then
    record_failure "Unsupported platform: $(uname -s)"
    print_report
    exit 0
  fi

  if [ ! -f "$TARGET_SCRIPT" ]; then
    record_failure "Missing platform script: $TARGET_SCRIPT"
    print_report
    exit 0
  fi

  # shellcheck source=/dev/null
  . "$TARGET_SCRIPT"

  report_path_setup
  install_platform_packages
  set_git_default_branch
  set_default_shell_to_zsh
  stow_packages
  install_tpm
  install_tmux_plugins
  run_mise_install
  print_report
}

print_report() {
  log ""
  log "Bootstrap report"
  log "================"
  log "Succeeded: ${#SUCCESS_ITEMS[@]}"
  for item in "${SUCCESS_ITEMS[@]}"; do
    log "  - $item"
  done

  log "Warnings: ${#WARNING_ITEMS[@]}"
  for item in "${WARNING_ITEMS[@]}"; do
    log "  - $item"
  done

  log "Failures: ${#FAILED_ITEMS[@]}"
  for item in "${FAILED_ITEMS[@]}"; do
    log "  - $item"
  done
}

main "$@"
