#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR=$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(CDPATH="" cd -- "$SCRIPT_DIR/.." && pwd)
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
export IS_WSL=0
MISE_BIN=""

export PATH="$HOME/.local/bin:$PATH"

SUCCESS_ITEMS=()
WARNING_ITEMS=()
FAILED_ITEMS=()
COMMAND_FAILURE_LABELS=()
COMMAND_FAILURE_COMMANDS=()
COMMAND_FAILURE_OUTPUTS=()

PACKAGES=(zsh starship mise ghostty opencode tmux git)
HEADLESS=0
SKIP_AI=0
OMARCHY=0
parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --headless) HEADLESS=1 ;;
      --skip-ai) SKIP_AI=1 ;;
      --omarchy) OMARCHY=1 ;;
      -h|--help) printf 'Usage: %s [--headless] [--skip-ai] [--omarchy]\n' "$0"; exit 0 ;;
      *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
  done
}


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

  bash -o pipefail -c "$command" 2>&1 | tee "$output_file"
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
  local status=0
  shift

  for package in "$@"; do
    if brew list --formula "$package" >/dev/null 2>&1; then
      continue
    fi

    if ! install_brew_formula "$package"; then
      status=1
    fi
  done

  if [ "$status" -eq 0 ]; then
    record_success "$label already satisfied"
  else
    record_warning "$label had one or more package warnings"
  fi

  return "$status"
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

  if ! run_shell "Install JetBrainsMono Nerd Font" "unzip -o -j \"$archive\" '*.ttf' -d \"$fonts_dir\""; then
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

  install_path="$HOME/.local/bin/mise"
  install_dir="$HOME/.local/bin"

  run_shell "Create mise install directory" "${installer_prefix:+$installer_prefix }mkdir -p \"$install_dir\""
  run_shell "Install mise with official installer" "curl -fsSL https://mise.run | ${installer_prefix:+$installer_prefix }env MISE_INSTALL_PATH=\"$install_path\" sh"

  if ! resolve_mise_bin; then
    record_failure "mise was not found after installation"
    return 1
  fi

  export PATH="${MISE_BIN%/*}:$PATH"
  run_shell "Verify mise installation" "\"$MISE_BIN\" --version"
}

install_agent_browser() {
  # Chrome for Testing has no Linux ARM64 build; use the distro's Chromium.
  if [ "$(uname -s)" = Linux ] && [[ "$(uname -m)" = aarch64 || "$(uname -m)" = arm64 ]]; then
    case "${TARGET_SCRIPT##*/}" in
      bootstrap-ubuntu.sh)
        if apt-cache show chromium >/dev/null 2>&1; then
          run_shell "Install system Chromium" "$SUDO apt-get install -y --no-install-recommends chromium" || return 1
        else
          run_shell "Install system Chromium" "$SUDO apt-get install -y --no-install-recommends chromium-browser" || return 1
        fi ;;
      bootstrap-fedora.sh) install_dnf_packages "Install system Chromium" chromium || return 1 ;;
      bootstrap-arch.sh) install_pacman_packages "Install system Chromium" chromium || return 1 ;;
    esac
    local browser
    browser=$(command -v chromium || command -v chromium-browser) || return 1
    run_cmd "Configure agent-browser system runtime" "$MISE_BIN" -C "$HOME" exec -- node -e '
      const fs=require("node:fs"),path=require("node:path"),os=require("node:os");
      const p=path.join(os.homedir(),".agent-browser/config.json");
      const config=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
      config.executablePath=process.argv[1];
      fs.mkdirSync(path.dirname(p),{recursive:true});
      fs.writeFileSync(p,JSON.stringify(config,null,2)+"\n");' "$browser"
    return $?
  fi
  local flags=()
  if [ "${TARGET_SCRIPT##*/}" = bootstrap-ubuntu.sh ]; then
    flags+=(--with-deps)
  fi
  run_cmd "Install agent-browser Chromium runtime" "$MISE_BIN" -C "$HOME" exec -- agent-browser install "${flags[@]}"
}

install_claude() {
  if have claude; then
    record_success "Claude Code already installed"
    return 0
  fi
  local installer
  installer=$(mktemp) || return 1
  run_cmd "Download Claude Code native installer" curl -fsSL https://claude.ai/install.sh -o "$installer" || { rm -f "$installer"; return 1; }
  run_cmd "Install Claude Code" bash "$installer" 2.1.289
  local status=$?
  rm -f "$installer"
  [ "$status" -eq 0 ] && run_cmd "Verify Claude Code" "$HOME/.local/bin/claude" --version
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

  run_cmd "Set git default branch to main" git config --global init.defaultBranch main || return 1
  run_cmd "Set automatic Git upstreams" git config --global push.autoSetupRemote true
}

install_tpm() {
  local target="$TMUX_PLUGIN_MANAGER_PATH/tpm"
  run_cmd "Create tmux plugin directory" mkdir -p "$TMUX_PLUGIN_MANAGER_PATH" || return 1
  if [ -d "$target" ]; then
    record_success "tmux plugin manager already present"
    return 0
  fi
  run_shell "Install tmux plugin manager" "git clone https://github.com/tmux-plugins/tpm \"$target\""
}

install_tmux_plugins() {
  local tpm_bin="$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins"
  local tmux_conf="$HOME/.config/tmux/tmux.conf"
  local server="dotfiles-bootstrap-$$"
  local socket plugin status=0
  [ -x "$tpm_bin" ] && [ -f "$tmux_conf" ] || {
    record_warning "tmux configuration or TPM installer is unavailable"
    return 1
  }
  # A live isolated session lets TPM query options on a fresh machine.
  run_cmd "Start isolated tmux bootstrap server" tmux -L "$server" -f "$tmux_conf" new-session -d -s bootstrap || return 1
  socket=$(tmux -L "$server" display-message -p '#{socket_path}')
  run_cmd "Install tmux plugins" env TMUX="$socket,0,0" TMUX_PLUGIN_MANAGER_PATH="$TMUX_PLUGIN_MANAGER_PATH" "$tpm_bin" || status=1
  tmux -L "$server" kill-server >/dev/null 2>&1 || true
  while IFS= read -r plugin; do
    if [ ! -d "$TMUX_PLUGIN_MANAGER_PATH/${plugin##*/}/.git" ]; then
      record_warning "Declared tmux plugin missing: $plugin"
      status=1
    fi
  done < <(sed -n "s/^set -g @plugin '\(.*\)'$/\1/p" "$tmux_conf")
  return "$status"
}

set_default_shell_to_zsh() {
  local zsh_path
  local login_user
  login_user=$(id -un)
  local login_shell=""
  local passwd_entry=""

  if ! have zsh; then
    record_warning "zsh not installed yet, skipping default shell change"
    return 1
  fi

  zsh_path=$(command -v zsh)

  if [ "$(uname -s)" = "Darwin" ] && have dscl; then
    login_shell=$(dscl . -read "/Users/$login_user" UserShell 2>/dev/null | awk '{print $2}' || true)
  elif have getent; then
    passwd_entry=$(getent passwd "$login_user" 2>/dev/null || true)
  elif [ -r /etc/passwd ]; then
    passwd_entry=$(grep "^$login_user:" /etc/passwd 2>/dev/null || true)
  fi

  if [ -z "$login_shell" ] && [ -n "$passwd_entry" ]; then
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
    if [ -x /bin/zsh ] && grep -qx /bin/zsh /etc/shells; then
      zsh_path=/bin/zsh
    else
      record_warning "$zsh_path is not listed in /etc/shells"
      return 1
    fi
  fi

  if [ -n "$SUDO" ]; then
    run_cmd "Set zsh as default shell" "$SUDO" chsh -s "$zsh_path" "$login_user" || return 1
  else
    run_cmd "Set zsh as default shell" chsh -s "$zsh_path" "$login_user" || return 1
  fi

  passwd_entry=""
  login_shell=""
  if [ "$(uname -s)" = "Darwin" ] && have dscl; then
    login_shell=$(dscl . -read "/Users/$login_user" UserShell 2>/dev/null | awk '{print $2}' || true)
  elif have getent; then
    passwd_entry=$(getent passwd "$login_user" 2>/dev/null || true)
  elif [ -r /etc/passwd ]; then
    passwd_entry=$(grep "^$login_user:" /etc/passwd 2>/dev/null || true)
  fi

  if [ -z "$login_shell" ] && [ -n "$passwd_entry" ]; then
    login_shell=${passwd_entry##*:}
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

backup_stow_conflicts() {
  local package=$1
  local source_path rel_path target_path backup_path
  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)-$$
  # Only managed files: never adopt runtime files written through folded links.
  while IFS= read -r -d '' rel_path; do
    source_path="$DOTFILES_DIR/$rel_path"
    rel_path=${rel_path#"$package/"}
    [ "$rel_path" = .stow-local-ignore ] && continue
    target_path="$HOME/$rel_path"
    [ "$source_path" -ef "$target_path" ] && continue
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
      backup_path="$target_path.bootstrap-backup-$timestamp"
      run_cmd "Backup existing $rel_path before stow" mv "$target_path" "$backup_path" || return 1
    fi
  done < <(git -C "$DOTFILES_DIR" ls-files -z --cached --others --exclude-standard -- "$package")
}

stow_packages() {
  local package
  local status=0
  for package in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$package" ]; then
      backup_stow_conflicts "$package" || { status=1; continue; }
      run_cmd "Stow $package" stow --dir="$DOTFILES_DIR" --no-folding --target="$HOME" --restow "$package" || status=1
    else
      record_warning "Missing stow package: $package"
      status=1
    fi
  done
  return "$status"
}

run_mise_install() {
  if ! resolve_mise_bin; then
    record_warning "mise not available, skipping mise install"
    return 1
  fi
  export PATH="${MISE_BIN%/*}:$PATH"
  run_cmd "Trust canonical mise config" "$MISE_BIN" trust "$DOTFILES_DIR/mise/.config/mise/config.toml" || return 1
  local github_token=""
  if have gh; then
    github_token=$(gh auth token 2>/dev/null) || true
  fi
  # Pass existing GitHub auth only in the child environment, never command logs.
  if [ -n "$github_token" ]; then
    GH_TOKEN="$github_token" run_cmd "Install mise-managed tools" env MISE_GLOBAL_CONFIG_FILE="$DOTFILES_DIR/mise/.config/mise/config.toml" "$MISE_BIN" -C "$HOME" install --jobs 4
  else
    run_cmd "Install mise-managed tools" env MISE_GLOBAL_CONFIG_FILE="$DOTFILES_DIR/mise/.config/mise/config.toml" "$MISE_BIN" -C "$HOME" install --jobs 4
  fi
}

install_platform_gui_apps() {
  return 0
}

report_path_setup() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*)
      record_success "$HOME/.local/bin already on PATH"
      ;;
    *)
      record_warning "$HOME/.local/bin is not on PATH; add it if fallback installers use it"
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

is_omarchy() {
  [ "$(uname -s)" = Linux ] && {
    [ -f /usr/share/omarchy/default/bash/rc ] ||
      [ -f "${OMARCHY_PATH:-$HOME/.local/share/omarchy}/default/bash/rc" ]
  }
}

required_step() {
  local label=$1
  shift
  if ! "$@"; then
    record_failure "$label"
    return 1
  fi
}

main() {
  parse_args "$@"

  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    printf 'Run bootstrap as your normal user, with sudo access.\n' >&2
    return 1
  fi
  # Omarchy owns its desktop, shell and agent launchers. Never apply the generic
  # Stow/chsh path over an existing Omarchy install, even without --omarchy.
  if [ "$OMARCHY" -eq 1 ] || is_omarchy; then
    . "$SCRIPT_DIR/bootstrap-omarchy.sh"
    bootstrap_omarchy
    return $?
  fi
  if ! detect_platform; then
    record_failure "Unsupported platform: $(uname -s)"
    print_report
    exit 1
  fi

  if [ ! -f "$TARGET_SCRIPT" ]; then
    record_failure "Missing platform script: $TARGET_SCRIPT"
    print_report
    exit 1
  fi

  # shellcheck source=/dev/null
  . "$TARGET_SCRIPT"

  report_path_setup
  ensure_sudo_access
  required_step "Native bootstrap packages" install_platform_packages || { print_report; return 1; }
  required_step "mise installation" install_mise || { print_report; return 1; }
  if [ "$HEADLESS" -eq 0 ]; then
    install_jetbrainsmono_nerd_font
    install_platform_gui_apps
  fi
  required_step "Git defaults" set_git_default_branch
  set_default_shell_to_zsh
  required_step "Stow packages" stow_packages || { print_report; return 1; }
  required_step "mise tools" run_mise_install || { print_report; return 1; }
  required_step "TPM installation" install_tpm
  required_step "tmux plugin installation" install_tmux_plugins
  required_step "Claude Code installation" install_claude
  required_step "Browser automation runtime" install_agent_browser
  if [ "$SKIP_AI" -eq 0 ]; then
    required_step "AI skills (private repo requires GitHub authentication)" run_cmd "Restore AI skills" "$MISE_BIN" exec -- node "$SCRIPT_DIR/setup-ai.mjs"
  fi
  print_report
  [ "${#FAILED_ITEMS[@]}" -eq 0 ]
}

print_report() {
  set +u

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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
