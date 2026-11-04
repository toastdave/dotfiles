# Developer machine setup

Canonical machine configuration: [toastdave/dotfiles](https://github.com/toastdave/dotfiles).
Personal skill source: [nyyx-io/skills](https://github.com/nyyx-io/skills) (private).
Stow links configuration; mise manages runtimes and portable CLI tools; Homebrew owns native Mac packages/apps and each Linux distribution owns its system packages; `ai/skills.json` declares upstream skills at explicit Git commits.

## New Mac

Use your normal user. Install Apple's Command Line Tools (`xcode-select --install`) and [Homebrew](https://brew.sh), then:

```sh
git clone https://github.com/toastdave/dotfiles.git ~/dotfiles
cd ~/dotfiles
brew install gh
gh auth login
gh auth setup-git
./scripts/bootstrap.sh --skip-ai
exec zsh -l
```

Existing GitHub authentication is passed privately to mise downloads to avoid anonymous API limits. Bootstrap installs the native essentials, Ghostty/VS Code, terminal font, mise tools (including native Codex CLI and Claude Code), the agent-browser Chromium runtime, and tmux plugins. GUI/font installs are best effort; required setup errors return a failing exit status. Intel and Apple Silicon Homebrew prefixes are supported.

## Daily workflow and tool ownership

Requires mise 2026.10.18 or newer. Update standalone mise with `mise self-update`, or a Homebrew-owned mise with `brew upgrade mise`. After pulling this repository, run setup to reconcile the machine:

```sh
cd ~/dotfiles
git pull --ff-only
mise run setup
mise run doctor
# Update declared mise tools and already-installed packages from the Mac Brewfiles:
mise run update
# Preview without changing installed packages:
mise run update -- --dry-run
```

The same tasks are installed globally, so they also work outside the checkout. Project tasks with the same names take precedence; use `mise -C ~/dotfiles run setup` to select this repository explicitly. A fresh machine first runs `./scripts/bootstrap.sh` to install mise and link configuration. `mise run setup -- --headless --skip-ai` defers GUI setup and AI skills. `mise run setup -- --mac-extras` also installs the optional Mac Brewfile; updates never install optional applications that are absent.

- The shared mise manifest owns language runtimes, package managers, portable terminal tools, and the native `claude`/`codex` CLIs. Update agents through mise; Claude self-updates are disabled in the managed environment. Desktop Claude and Codex apps remain separate Homebrew casks.
- `macos/Brewfile.core` owns native bootstrap dependencies, Erlang build dependencies, and the deliberate Mac terminal-tool exceptions `btop`, `git-delta`, and `fd`. `macos/Brewfile` owns optional native tools and applications. Tasks invoke actual Homebrew, preserving its app, service, and installation behavior. The mise `brew:`/`brew-cask:` bootstrap adapters are not used.
- Linux system/build packages use apt, dnf, or pacman. Use the distribution updater for OS/desktop upgrades; on Omarchy use `omarchy update`. `mise run update` updates global mise tools without modifying project pins or silently upgrading the OS.
- A command has one declared owner. Homebrew's own Node/Ruby dependencies may coexist with development runtimes. Setup verifies both native agents before removing obsolete agent CLI casks/npm installs, rebuilds shims, and leaves credentials, conversations and desktop apps alone. Running obsolete npm agent versions are retained until their sessions exit; rerun setup afterward. An active Homebrew agent must be closed before its CLI cask can be removed.

OpenCode configuration is seeded only when both its JSON and JSONC configs are absent; existing local MCPs and preferences survive setup, including `--skip-ai`. Setup ends with doctor checks. Doctor checks executable ownership as well as availability, catches duplicate agent CLI casks, and verifies that global tasks point to this checkout. Existing Omarchy account dispatchers are preserved. Pulling alone does not migrate installations; run setup on each machine. Moving a checkout also requires setup to refresh global task paths.

## New Linux machine

Use a normal user with sudo access. Supported package managers: Ubuntu/Debian (`apt`), Fedora (`dnf`), Arch (`pacman`). Install Git, GitHub CLI (`gh`), and sudo through your distribution first. Authenticate with `gh auth login` and `gh auth setup-git`, then:

```sh
git clone https://github.com/toastdave/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh --headless --skip-ai
exec zsh -l
```

Linux ARM64 uses distribution Chromium; bootstrap records its executable path in the local agent-browser config.

Omit `--headless` for a desktop: native GUI installation is best effort. Ubuntu/Debian use snap, Fedora uses Microsoft RPM and Ghostty COPR, Arch uses native packages. WSL automatically skips Linux GUI installs; install VS Code on Windows with Remote WSL. WSL is the supported Windows development path. Native Windows bootstrap remains outside scope; the Bash/Stow setup is not claimed to support it.

## Omarchy

Install Omarchy first, then run this as your normal user in its Bash terminal:

```sh
gh auth login
gh auth setup-git
git clone https://github.com/toastdave/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh --omarchy
```

The bootstrap also detects an existing Omarchy installation automatically. It keeps Omarchy's Bash, prompt, completion, desktop, terminal themes, tmux configuration, Git identity, and agent launchers. It reuses Omarchy's mise installation and native Codex/Claude/OpenCode/Pi tool names, preserving account dispatchers and the normal `omarchy update` path. Native agents, including Codex and Pi, use `latest` by default because Omarchy's launchers select rolling releases. Pi extension versions remain pinned.

Our runtime defaults are derived from the shared mise manifest and written to `~/.config/mise/conf.d/10-dotfiles.toml`. Existing `~/.config/mise/config.toml` and project tool declarations take precedence, so an existing runtime selection remains authoritative. Additional Linux build dependencies and Railway CLI are installed; the existing Chromium/Chrome is reused for agent-browser, or Chromium is installed if needed. This profile does not install the optional Mac Brewfile applications, mobile SDKs, or desktop plugins.

Setup adds a managed source block to `~/.bashrc` for our Bash shortcuts and optional Android SDK paths. It merges the Railway MCP declaration from `ai/pi/mcp.json` into Codex, Claude, OpenCode (JSON or JSONC), and Pi without replacing existing named servers. Pi keeps its theme, model and other preferences; our extension versions are reconciled while unrelated packages and package-specific options remain intact. Working agreements are added in managed blocks alongside existing client instructions. Modified files have recoverable copies under `~/.local/state/dotfiles/backups/`; comments, permissions, and existing symlinks are retained. No login credentials are copied between machines.

The normal install restores the declared vendor pins and links personal skills from the private skills repository. Existing skills with the same vendor names are backed up before replacement; unrelated skills remain. Reruns resume completed pinned installs. To defer skill downloads and extension installation, use `--skip-ai`, then rerun without it when ready. Open a new Bash terminal after setup and authenticate agents and services individually.

```sh
# Reconcile after pulling dotfiles updates; safe to rerun.
./scripts/bootstrap.sh --omarchy
# Check configuration, tools, links and installed extension versions.
mise exec -- node scripts/doctor.mjs --omarchy
# When skills/extensions were deliberately deferred:
mise exec -- node scripts/doctor.mjs --omarchy --skip-ai
```

Omarchy references: [Bash customizations](https://omarchy.org/manual/dotfiles/), [agent launchers and updates](https://omarchy.org/manual/ai/), [mise config directories](https://mise.jdx.dev/directories.html).

## Restore AI skills

After the core install, authenticate GitHub to access your private personal skills:

```sh
gh auth login
gh auth setup-git
cd ~/dotfiles
mise exec -- node scripts/setup-ai.mjs
mise exec -- node scripts/doctor.mjs
```

The restore script clones personal skills to `~/code/projects/skills` (override with `PERSONAL_SKILLS_DIR`). An existing checkout remains authoritative, including uncommitted work. Upstream skills install through the pinned skills.sh CLI and manifest commit refs into `~/.agents/skills`. Claude, Codex, OpenCode, and Pi share that source through links. Personal skills link to their Git checkout. Global working agreements live in `ai/.agents/AGENTS.md`; Claude imports them and Codex and Pi link to them. Pi’s initial preferences, pinned extensions, and Railway MCP declaration live in `ai/pi/`; existing local preferences are preserved. After Omarchy setup, the restore script detects its managed Bash block and retains additive merging automatically; `--merge` selects that behavior explicitly.

For an existing machine, normalize links without fetching or changing skill contents:

```sh
mise exec -- node scripts/setup-ai.mjs --link-existing
```

If an upstream fetch fails, rerun with `--resume` to skip already completed manifest revisions. A normal run reinstalls vendor files from their pinned source.

The portable install inputs are in `ai/skills.json`: CLI version, source repositories, exact vendor commits, and skill names. The CLI generates an installed-skill inventory on each machine at `$XDG_STATE_HOME/skills/.skill-lock.json` when `XDG_STATE_HOME` is set, otherwise `~/.agents/.skill-lock.json`. No existing inventory is required for a fresh install. Custom skills are linked before vendor downloads, and each completed vendor source is linked immediately, so a later download failure leaves those skills usable.

Conflicting copies and dead shared-skill links are moved to `~/.local/state/dotfiles/backups/<run>/`. Stow saves conflicting configuration beside its original path with `.bootstrap-backup-*`. Neither script uses `--adopt`, resets a checkout, or commits authentication.

Authenticate Claude, Codex, OpenCode, Pi, GitHub, and infrastructure CLIs on each new machine. Restore SSH keys from your secure backup or generate new ones; set Git identity explicitly:

```sh
git config --global user.name 'Your Name'
git config --global user.email 'you@example.com'
```

## Optional Mac developer applications

The audited native developer extras are captured in `macos/Brewfile`:

```sh
brew bundle --file=macos/Brewfile
colima start
```

This includes Docker/Colima, infrastructure CLIs, mobile tools, media/CAD utilities, and developer apps. It is optional and includes large installations. On Linux, use the distribution's Docker Engine setup and install project-specific SDKs/tooling as needed. This bootstrap does not reproduce Xcode, simulators, Android system images, signing certificates, or licensed applications; install those for the projects you work on. Android environment paths use the platform convention and respect an existing `ANDROID_HOME`/`JAVA_HOME`.

## Desktop AI and local integrations

Desktop plugin state, project trust, computer-use hooks, auth databases, and machine-specific MCP commands remain app-managed/local. Do not copy the entire `~/.codex/config.toml`, `~/.claude`, or other application state into this public repository.

Plugin preferences from `~/.codex/config.toml` and Claude settings are captured in `ai/desktop-plugins.json`. The app-installed inventory can differ; reinstall supported plugins through Codex on each machine. Claude currently enables `figma@claude-plugins-official`. Mac computer-use and iOS/macOS plugins need their platform tools. Remote MCPs need fresh authentication. Pencil's old hardcoded Linux path was removed from shared OpenCode configuration; configure it locally only on machines with Pencil installed. Put private shell customizations in `~/.zshrc.local`.

## Maintenance and version policy

- Edit linked configuration in this repository, and edit personal skills in their repository.
- Commit and push both repositories after reviewing their changes. Runtime caches, logs, credentials, and installed vendor copies stay out of Git.
- Most mise tools, including Codex CLI, intentionally use `latest`/`lts`; Bun, Python, pnpm, Pi on generic setups, Jujutsu, Rust, Erlang/Elixir, and Linux convenience binaries are pinned. Omarchy keeps its native Pi launcher on `latest`. This restores the declared setup, not a byte-identical copy of every tool. Use project mise configs/lockfiles for project reproducibility.
- Update native agent CLIs with `mise upgrade claude codex`, or use `mise run update`. Omarchy can also update its native launchers through `omarchy update`. Declaring `latest` does not install updates automatically.
- Update vendor commit refs and skill names in `ai/skills.json` deliberately, then exercise restoration in a disposable home. Vendor revisions can rename skills; the script fails if a declared skill was not installed.
- `mise self-update` updates mise itself. Then `mise upgrade` updates rolling global tools. Managed agent CLIs update through mise; setup migrates previous Homebrew CLI casks after verifying their native replacements.
- Run `mise exec -- node scripts/doctor.mjs` after changes. It checks runtime availability, declarations, canonical configuration links, and skill links. It does not prove authentication or a mobile build.

For setup changes, run `npm ci --prefix scripts`, `npm test --prefix scripts`, `bash tests/stow.sh`, and `bash tests/tooling-runtime.sh`. The runtime smoke test downloads and runs native Claude/Codex plus the declared Bun/Python pins in isolated mise directories and verifies a repeat install is a no-op; it requires no agent login. CI runs these checks on macOS and Ubuntu. `bash tests/linux-container.sh` runs them in a disposable Debian container with actual Linux dependencies and cleans up its container/image. The configuration tests exercise first install, preservation of existing Omarchy settings and credentials, JSONC comments, shell sourcing, symlinks, backups, invalid-input recovery, and rerun idempotency. The restore integration test runs the pinned skills CLI with actual local Git repositories, checking fresh installs with and without XDG state, resume, and usable custom skills after a vendor failure. It downloads the CLI through npm when uncached. A real Omarchy desktop still needs validation for desktop shortcuts, theming and graphical agent integrations.

Pi uses the current `@earendil-works` package scope ([migration notice](https://pi.dev/changelog/2026/5/7/pi-has-a-new-home)).

Source documentation: [mise configuration](https://mise.jdx.dev/configuration.html), [skills.sh CLI](https://github.com/vercel-labs/skills), [official OpenAI skill documentation](https://learn.chatgpt.com/docs/build-skills), [Claude installation](https://code.claude.com/docs/en/setup).
