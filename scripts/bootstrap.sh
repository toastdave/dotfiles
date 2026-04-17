#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DOTFILES_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
IS_WSL=0
MISE_BIN=""

export PATH="$HOME/.local/bin:$PATH"

SUCCESS_ITEMS=()
WARNING_ITEMS=()
FAILED_ITEMS=()
COMMAND_FAILURE_LABELS=()
COMMAND_FAILURE_COMMANDS=()
COMMAND_FAILURE_OUTPUTS=()

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

log_step() {
  log ""
  log "==> $1"
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

record_command_failure() {
  local label=$1
  local command=$2
  local output=$3

  COMMAND_FAILURE_LABELS+=("$label")
  COMMAND_FAILURE_COMMANDS+=("$command")
  COMMAND_FAILURE_OUTPUTS+=("$output")
}

format_command() {
  local arg
  local formatted=""
  local quoted

  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    if [ -n "$formatted" ]; then
      formatted="$formatted $quoted"
    else
      formatted="$quoted"
    fi
  done

  printf '%s' "$formatted"
}

run_live_command() {
  local label=$1
  local command=$2
  local output_file
  local output
  local status

  output_file=$(mktemp) || {
    record_warning "Unable to create temp log for $label"
    return 1
  }

  log_step "$label"
  log "    \$ $command"

  bash -lc "$command" 2>&1 | tee "$output_file"
  status=${PIPESTATUS[0]}
  output=$(<"$output_file")
  rm -f "$output_file"

  if [ "$status" -eq 0 ]; then
    record_success "$label"
    return 0
  fi

  record_command_failure "$label" "$command" "$output"
  record_warning "$label"
  return "$status"
}

run_cmd() {
  local label=$1
  local command
  local output_file
  local output
  local status
  shift

  command=$(format_command "$@")
  output_file=$(mktemp) || {
    record_warning "Unable to create temp log for $label"
    return 1
  }

  log_step "$label"
  log "    \$ $command"

  "$@" 2>&1 | tee "$output_file"
  status=${PIPESTATUS[0]}
  output=$(<"$output_file")
  rm -f "$output_file"

  if [ "$status" -eq 0 ]; then
    record_success "$label"
    return 0
  fi

  record_command_failure "$label" "$command" "$output"
  record_warning "$label"
  return "$status"
}

run_shell() {
  local label=$1
  local command=$2

  run_live_command "$label" "$command"
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

install_brew_formulas() {
  local label=$1
  local package
  local missing_packages=()
  shift

  for package in "$@"; do
    if ! brew list --formula "$package" >/dev/null 2>&1; then
      missing_packages+=("$package")
    fi
  done

  if [ "${#missing_packages[@]}" -eq 0 ]; then
    record_success "$label already satisfied"
    return 0
  fi

  run_shell "$label" "brew install ${missing_packages[*]}"
}

install_apt_package() {
  local package=$1
  run_shell "Install $package with apt" "$SUDO apt-get install -y $package"
}

install_apt_packages() {
  local label=$1
  shift
  run_shell "$label" "$SUDO apt-get install -y $*"
}

install_pacman_package() {
  local package=$1
  run_shell "Install $package with pacman" "$SUDO pacman -S --noconfirm --needed $package"
}

install_pacman_packages() {
  local label=$1
  shift
  run_shell "$label" "$SUDO pacman -S --noconfirm --needed $*"
}

install_dnf_package() {
  local package=$1
  run_shell "Install $package with dnf" "$SUDO dnf install -y $package"
}

install_dnf_packages() {
  local label=$1
  shift
  run_shell "$label" "$SUDO dnf install -y $*"
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

have_jetbrainsmono_nerd_font() {
  local match=""
  local linux_fonts_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

  case "$(uname -s)" in
    Darwin)
      if compgen -G "$HOME/Library/Fonts/JetBrainsMonoNerdFont*.ttf" >/dev/null; then
        return 0
      fi
      if compgen -G "$HOME/Library/Fonts/JetBrainsMonoNerdFont*.otf" >/dev/null; then
        return 0
      fi
      ;;
    *)
      if have fc-match; then
        match=$(fc-match "JetBrainsMono Nerd Font" 2>/dev/null || true)
        case "$match" in
          *JetBrainsMonoNerdFont*)
            return 0
            ;;
        esac
      fi

      if compgen -G "$linux_fonts_dir/JetBrainsMonoNerdFont*.ttf" >/dev/null; then
        return 0
      fi
      if compgen -G "$linux_fonts_dir/JetBrainsMonoNerdFont*.otf" >/dev/null; then
        return 0
      fi
      ;;
  esac

  return 1
}

install_jetbrainsmono_nerd_font() {
  local archive=""
  local fonts_dir=""
  local tmpdir=""

  if have_jetbrainsmono_nerd_font; then
    record_success "JetBrainsMono Nerd Font already installed"
    return 0
  fi

  if ! have curl; then
    record_warning "curl is not available, skipping JetBrainsMono Nerd Font install"
    return 1
  fi

  if ! have unzip; then
    record_warning "unzip is not available, skipping JetBrainsMono Nerd Font install"
    return 1
  fi

  case "$(uname -s)" in
    Darwin)
      fonts_dir="$HOME/Library/Fonts"
      ;;
    *)
      fonts_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
      ;;
  esac

  tmpdir=$(mktemp -d) || {
    record_warning "Unable to create temp directory for font install"
    return 1
  }
  archive="$tmpdir/JetBrainsMono.zip"

  if ! run_shell "Create user font directory" "mkdir -p \"$fonts_dir\""; then
    rm -rf "$tmpdir"
    return 1
  fi

  if ! run_shell "Download JetBrainsMono Nerd Font" "curl -fsSL -o \"$archive\" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
    rm -rf "$tmpdir"
    return 1
  fi

  if ! run_shell "Install JetBrainsMono Nerd Font" "unzip -o -j \"$archive\" '*.ttf' '*.otf' -d \"$fonts_dir\""; then
    rm -rf "$tmpdir"
    return 1
  fi

  if [ "$(uname -s)" = "Linux" ] && have fc-cache; then
    run_shell "Refresh font cache" "fc-cache -f \"$fonts_dir\""
  fi

  rm -rf "$tmpdir"
}

resolve_mise_bin() {
  local candidate=""
  local command_path=""
  local candidates=()

  if command_path=$(command -v mise 2>/dev/null); then
    candidates+=("$command_path")
  fi

  candidates+=("/usr/local/bin/mise" "/opt/homebrew/bin/mise" "$HOME/.local/bin/mise")

  for candidate in "${candidates[@]}"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      MISE_BIN="$candidate"
      return 0
    fi
  done

  MISE_BIN=""
  return 1
}

install_mise() {
  local install_path=""
  local install_dir=""
  local installer_prefix=""

  if resolve_mise_bin; then
    record_success "mise already available at $MISE_BIN"
    return 0
  fi

  if ! have curl; then
    record_failure "curl is required to install mise"
    return 1
  fi

  if [ -n "$SUDO" ] || [ "${EUID:-$(id -u)}" -eq 0 ] || [ -w /usr/local/bin ]; then
    install_path="/usr/local/bin/mise"
    install_dir="/usr/local/bin"
    installer_prefix="$SUDO"
  else
    install_path="$HOME/.local/bin/mise"
    install_dir="$HOME/.local/bin"
  fi

  run_shell "Create mise install directory" "${installer_prefix:+$installer_prefix }mkdir -p \"$install_dir\""
  run_shell "Install mise with official installer" "curl -fsSL https://mise.run | ${installer_prefix:+$installer_prefix }env MISE_INSTALL_PATH=\"$install_path\" sh"

  if ! resolve_mise_bin; then
    record_failure "mise was not found after installation"
    return 1
  fi

  export PATH="${MISE_BIN%/*}:$PATH"
  run_shell "Verify mise installation" "\"$MISE_BIN\" --version"
}

ensure_sudo_access() {
  if [ -z "$SUDO" ]; then
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
      record_success "Running as root, sudo not required"
      return 0
    fi

    record_warning "sudo is not available; privileged install steps may fail"
    return 1
  fi

  run_shell "Refresh sudo credentials" "$SUDO -v"
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
  local login_shell=""
  local passwd_entry=""

  if ! have zsh; then
    record_warning "zsh not installed yet, skipping default shell change"
    return 1
  fi

  zsh_path=$(command -v zsh)

  if have getent; then
    passwd_entry=$(getent passwd "$USER" 2>/dev/null || true)
  elif [ -r /etc/passwd ]; then
    passwd_entry=$(grep "^$USER:" /etc/passwd 2>/dev/null || true)
  fi

  if [ -n "$passwd_entry" ]; then
    login_shell=${passwd_entry##*:}
  fi

  if [ "$login_shell" = "$zsh_path" ]; then
    record_success "zsh already set as login shell"
    if [ "${SHELL:-}" != "$zsh_path" ]; then
      record_warning "Current session still reports ${SHELL:-unknown}; start a new login shell to pick up zsh"
    fi
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

  if ! run_shell "Set zsh as default shell" "chsh -s \"$zsh_path\" \"$USER\""; then
    return 1
  fi

  passwd_entry=""
  if have getent; then
    passwd_entry=$(getent passwd "$USER" 2>/dev/null || true)
  elif [ -r /etc/passwd ]; then
    passwd_entry=$(grep "^$USER:" /etc/passwd 2>/dev/null || true)
  fi

  if [ -n "$passwd_entry" ]; then
    login_shell=${passwd_entry##*:}
  else
    login_shell=""
  fi

  if [ "$login_shell" != "$zsh_path" ]; then
    record_warning "Login shell is still ${login_shell:-unknown} after chsh"
    return 1
  fi

  record_success "Verified zsh as login shell"
  if [ "${SHELL:-}" != "$zsh_path" ]; then
    record_warning "Current session still reports ${SHELL:-unknown}; start a new login shell to pick up zsh"
  fi
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
  if ! resolve_mise_bin; then
    record_warning "mise not available, skipping mise install"
    return 1
  fi
  export PATH="${MISE_BIN%/*}:$PATH"
  run_shell "Install mise-managed tools" "\"$MISE_BIN\" install --raw"
}

install_platform_gui_apps() {
  return 0
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
        fedora)
          TARGET_SCRIPT="$SCRIPT_DIR/bootstrap-fedora.sh"
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
  ensure_sudo_access
  install_platform_packages
  install_mise
  install_jetbrainsmono_nerd_font
  install_platform_gui_apps
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

  log "Command errors: ${#COMMAND_FAILURE_LABELS[@]}"
  for i in "${!COMMAND_FAILURE_LABELS[@]}"; do
    log "  - ${COMMAND_FAILURE_LABELS[$i]}"
    log "    command: ${COMMAND_FAILURE_COMMANDS[$i]}"
    if [ -n "${COMMAND_FAILURE_OUTPUTS[$i]}" ]; then
      while IFS= read -r line; do
        log "    output: $line"
      done <<< "${COMMAND_FAILURE_OUTPUTS[$i]}"
    else
      log "    output: <none>"
    fi
  done
}

main "$@"
