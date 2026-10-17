#!/usr/bin/env bash
# Sourced by bootstrap.sh. Reuse its command reporting; keep the Omarchy desktop in charge.

omarchy_configure() {
  run_cmd "Merge Omarchy tools, clients and Bash configuration" "$MISE_BIN" -C "$HOME" exec node -- node "$SCRIPT_DIR/setup-omarchy.mjs"
}

omarchy_install_tools() {
  local tools=()
  local tool github_token=""
  # Pass tool names as real arguments, never eval or shell text from configuration.
  local tool_list
  tool_list=$("$MISE_BIN" -C "$HOME" exec node -- node "$SCRIPT_DIR/setup-omarchy.mjs" --list-tools) || return 1
  tools=()
  while IFS= read -r tool; do tools+=("$tool"); done <<< "$tool_list"
  if have gh; then github_token=$(gh auth token 2>/dev/null) || true; fi
  if [ -n "$github_token" ]; then
    GH_TOKEN="$github_token" run_cmd "Install merged mise tools" "$MISE_BIN" -C "$HOME" install --jobs 4 "${tools[@]}"
  else
    run_cmd "Install merged mise tools" "$MISE_BIN" -C "$HOME" install --jobs 4 "${tools[@]}"
  fi
}

omarchy_browser() {
  local browser=""
  browser=$(command -v chromium || command -v google-chrome-stable || command -v google-chrome) || true
  if [ -z "$browser" ]; then
    install_pacman_packages "Install browser automation runtime" chromium || return 1
    browser=$(command -v chromium) || return 1
  fi
  run_cmd "Configure agent-browser runtime" "$MISE_BIN" -C "$HOME" exec -- node "$SCRIPT_DIR/setup-omarchy.mjs" --browser "$browser"
}

bootstrap_omarchy() {
  if ! is_omarchy || ! have pacman; then
    record_failure "--omarchy requires an existing Omarchy installation with pacman"
    print_report
    return 1
  fi
  if [ -n "${MISE_GLOBAL_CONFIG_FILE:-}" ]; then
    record_failure "Unset MISE_GLOBAL_CONFIG_FILE so Omarchy's mise fragments remain active"
    print_report
    return 1
  fi
  resolve_mise_bin || { record_failure "Omarchy's mise installation is missing"; print_report; return 1; }
  required_step "sudo access" ensure_sudo_access || { print_report; return 1; }
  required_step "Build and setup dependencies" install_pacman_packages "Install Omarchy developer dependencies" \
    git curl github-cli base-devel openssl ncurses unixodbc unzip || { print_report; return 1; }
  required_step "Setup Node version" run_cmd "Verify Node supports the pinned skills installer" \
    "$MISE_BIN" -C "$HOME" exec node -- node -e \
    'const [major,minor]=process.versions.node.split(".").map(Number);if(major<22||(major===22&&minor<20)){console.error("Setup requires Node >=22.20. Update your global mise Node selection, or run setup with a newer Node.");process.exit(1)}' || { print_report; return 1; }
  required_step "Configuration merge dependencies" run_cmd "Install locked setup dependencies" \
    "$MISE_BIN" -C "$HOME" exec node -- npm ci --prefix "$SCRIPT_DIR" --ignore-scripts --no-audit --no-fund || { print_report; return 1; }
  required_step "Omarchy configuration" omarchy_configure || { print_report; return 1; }
  required_step "mise tools" omarchy_install_tools || { print_report; return 1; }
  required_step "Browser runtime" omarchy_browser || { print_report; return 1; }
  if [ "$SKIP_AI" -eq 0 ]; then
    required_step "Shared skills and Pi extensions" run_cmd "Restore AI skills additively" \
      "$MISE_BIN" -C "$HOME" exec -- node "$SCRIPT_DIR/setup-ai.mjs" --merge --resume || { print_report; return 1; }
  fi
  local doctor_args=(--omarchy)
  [ "$SKIP_AI" -eq 0 ] || doctor_args+=(--skip-ai)
  required_step "Omarchy validation" run_cmd "Check developer setup" \
    "$MISE_BIN" -C "$HOME" exec -- node "$SCRIPT_DIR/doctor.mjs" "${doctor_args[@]}"
  print_report
  log "Open a new Bash terminal, then authenticate your agents and services."
  [ "${#FAILED_ITEMS[@]}" -eq 0 ]
}
