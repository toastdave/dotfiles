#!/usr/bin/env bash
# Real native downloads and execution in an isolated mise installation.
set -euo pipefail
ROOT=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd -P)
MISE_EXE=$(command -v mise)
RUNTIME_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-runtime.XXXXXX")
trap 'rm -rf "$RUNTIME_DIR"' EXIT
export MISE_CONFIG_DIR="$RUNTIME_DIR/config"
export MISE_DATA_DIR="$RUNTIME_DIR/data"
export MISE_CACHE_DIR="$RUNTIME_DIR/cache"
export MISE_STATE_DIR="$RUNTIME_DIR/state"
export MISE_GLOBAL_CONFIG_FILE="$MISE_CONFIG_DIR/config.toml"
export MISE_YES=1
mkdir -p "$MISE_CONFIG_DIR"
cat > "$MISE_GLOBAL_CONFIG_FILE" <<'TOML'
[tools]
claude = "latest"
codex = "latest"
TOML
# Exercise the actual portable runtime pins, not duplicate test versions.
node --input-type=module -e 'import {readFileSync} from "node:fs"; const {TOML}=await import(process.argv[1]); const {tools}=TOML.parse(readFileSync(process.argv[2],"utf8")); for(const name of ["bun","python"]) console.log(`${name} = ${JSON.stringify(tools[name])}`);' "$ROOT/scripts/lib/config.mjs" "$ROOT/mise/.config/mise/config.toml" >> "$MISE_GLOBAL_CONFIG_FILE"
cat >> "$MISE_GLOBAL_CONFIG_FILE" <<'TOML'
[env]
DISABLE_AUTOUPDATER = "1"
TOML
"$MISE_EXE" -C "$RUNTIME_DIR" install
"$MISE_EXE" -C "$RUNTIME_DIR" exec -- claude --version
"$MISE_EXE" -C "$RUNTIME_DIR" exec -- codex --version
"$MISE_EXE" -C "$RUNTIME_DIR" exec -- bun --version
"$MISE_EXE" -C "$RUNTIME_DIR" exec -- python --version
# Confirm another install is a no-op, with the same active versions.
"$MISE_EXE" -C "$RUNTIME_DIR" install --dry-run-code
"$MISE_EXE" -C "$RUNTIME_DIR" which claude
"$MISE_EXE" -C "$RUNTIME_DIR" which codex

# Exercise the same replacement verification used by the production migration.
"$MISE_EXE" -C "$RUNTIME_DIR" exec -- node --input-type=module -e 'const {verifyAgents}=await import(process.argv[1]); verifyAgents();' "$ROOT/scripts/lib/tooling.mjs"
