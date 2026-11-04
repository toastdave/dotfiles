#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DOTFILES_DIR=$(CDPATH="" cd -- "$SCRIPT_DIR/.." && pwd -P)
# Reuse platform detection and reporting without running bootstrap's main.
. "$SCRIPT_DIR/bootstrap.sh"
action=${1:-help}
[ "$#" -eq 0 ] || shift
case "$action" in
  setup)
    extras=0
    setup_args=()
    for arg in "$@"; do
      if [ "$arg" = --mac-extras ]; then extras=1; else setup_args+=("$arg"); fi
    done
    if [ "$extras" -eq 1 ] && [ "$(uname -s)" != Darwin ]; then
      printf '%s\n' '--mac-extras requires macOS' >&2; exit 2
    fi
    bash "$SCRIPT_DIR/bootstrap.sh" ${setup_args[@]+"${setup_args[@]}"}
    if [ "$extras" -eq 1 ]; then
      brew bundle install --no-upgrade --file="$DOTFILES_DIR/macos/Brewfile"
    fi
    ;;
  update)
    dry_run=0
    if [ "$#" -eq 1 ] && [ "$1" = --dry-run ]; then dry_run=1;
    elif [ "$#" -ne 0 ]; then printf '%s\n' 'Usage: mise run update [--dry-run]' >&2; exit 2; fi
    resolve_mise_bin || { printf '%s\n' 'mise is not installed' >&2; exit 1; }
    # Resolve from HOME, never an unrelated project or its pinned tool versions.
    if is_omarchy; then
      printf '%s\n' 'Updating mise tools; use omarchy update for the Omarchy OS and desktop.'
    fi
    if [ "$dry_run" -eq 1 ]; then
      "$MISE_BIN" -C "$HOME" upgrade --dry-run
      if [ "$(uname -s)" = Darwin ]; then
        "$MISE_BIN" -C "$HOME" exec -- node "$SCRIPT_DIR/update-brew.mjs" --dry-run
      fi
      exit 0
    fi
    "$MISE_BIN" -C "$HOME" upgrade
    "$MISE_BIN" -C "$HOME" exec -- npm ci --prefix "$SCRIPT_DIR" --ignore-scripts --no-audit --no-fund
    "$MISE_BIN" -C "$HOME" exec -- node "$SCRIPT_DIR/setup-tooling.mjs"
    if [ "$(uname -s)" = Darwin ]; then
      brew update
      "$MISE_BIN" -C "$HOME" exec -- node "$SCRIPT_DIR/update-brew.mjs"
    fi
    printf '%s\n' 'Open a new shell to load updated tool paths. Run mise run doctor after updating.'
    ;;
  doctor)
    resolve_mise_bin || { printf '%s\n' 'mise is not installed' >&2; exit 1; }
    exec "$MISE_BIN" -C "$HOME" exec -- node "$SCRIPT_DIR/doctor.mjs" "$@"
    ;;
  *) printf '%s\n' 'Usage: bash scripts/manage.sh setup [--headless] [--skip-ai] [--omarchy] [--mac-extras]' '       bash scripts/manage.sh update [--dry-run]' '       bash scripts/manage.sh doctor [--skip-ai] [--omarchy]'; exit 2 ;;
esac
