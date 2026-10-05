#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT
export HOME="$TEST_HOME"
. "$ROOT/scripts/bootstrap.sh"
# Seed real conflicts to verify recovery, then exercise real Stow twice.
printf 'existing login configuration\n' > "$HOME/.zprofile"
mkdir -p "$HOME/.config/git"
printf 'existing ignores\n' > "$HOME/.config/git/ignore"
stow_packages
stow_packages
[ "$HOME/.zshrc" -ef "$ROOT/zsh/.zshrc" ]
[ "$HOME/.zprofile" -ef "$ROOT/zsh/.zprofile" ]
[ "$HOME/.config/git/ignore" -ef "$ROOT/git/.config/git/ignore" ]
[ ! -L "$HOME/.config" ]
[ ! -e "$HOME/.config/opencode/skills" ]
compgen -G "$HOME/.zprofile.bootstrap-backup-*" >/dev/null
compgen -G "$HOME/.config/git/ignore.bootstrap-backup-*" >/dev/null
printf 'Stow first install, conflict recovery, and rerun passed.\n'
