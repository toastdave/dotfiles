#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd -P)
IMAGE=node:24-bookworm
NAME=dotfiles-tooling-validation-$$
owned_image=0
docker image inspect "$IMAGE" >/dev/null 2>&1 || owned_image=1
cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  if [ "$owned_image" -eq 1 ]; then
    docker image rm "$IMAGE" >/dev/null 2>&1 || printf 'Retained %s: Docker could not remove it (it may now be in use).\n' "$IMAGE" >&2
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
docker run --rm --name "$NAME" --mount "type=bind,source=$ROOT,target=/source,readonly" "$IMAGE" bash -euc '
  apt-get update -qq
  apt-get install -y -qq stow zsh ca-certificates curl git
  mkdir /work
  tar -C /source --exclude=.git --exclude=node_modules -cf - . | tar -C /work -xf -
  cd /work
  git init -q
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
  export MISE_YES=1
  mise trust /work/mise.toml
  npm ci --prefix scripts --ignore-scripts --no-audit --no-fund
  npm test --prefix scripts
  bash tests/stow.sh
  bash tests/tooling-runtime.sh
'
