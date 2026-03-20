# Dotfiles

This repository mirrors the user-managed shell, terminal, prompt, runtime, and tmux setup for a Unix-first development environment.

## Goals

- Keep curated config files under version control.
- Use GNU Stow to symlink config into `$HOME`.
- Use native package managers where possible.
- Use `mise` for language runtimes and developer tool versions.
- Prefer Zsh as the default shell wherever the platform allows it.
- Use WSL for Windows development, with the actual toolchain installed inside WSL.

## Repository layout

Each top-level directory is a Stow package. The contents inside each package mirror the path they should land at under `$HOME`.

```text
dotfiles/
  zsh/
    .zshrc
  starship/
    .config/starship/starship.toml
  mise/
    .config/mise/config.toml
  ghostty/
    .config/ghostty/config
  opencode/
    .config/opencode/package.json
  tmux/
    .config/tmux/tmux.conf
    .config/tmux/tmux.reset.conf
  scripts/
    bootstrap.sh
    bootstrap-macos.sh
    bootstrap-ubuntu.sh
    bootstrap-arch.sh
  README.md
```

Example: when you run `stow zsh` from the repo root, Stow creates `~/.zshrc` as a symlink back to `~/dotfiles/zsh/.zshrc`. Running `stow starship` creates `~/.config/starship/starship.toml` as a symlink to the file in this repo.

## What is managed here

- `zsh`: shell aliases and tool initialization
- `starship`: prompt theme
- `mise`: runtime versions
- `ghostty`: terminal preferences
- `opencode`: declarative plugin manifest only
- `tmux`: session and plugin configuration

## What is intentionally excluded

- caches and logs
- telemetry and generated state
- auth files and secrets such as SSH, GPG, or GitHub host tokens
- local databases and session history
- `node_modules`, lockfiles, and other generated dependency trees unless explicitly needed

## Bootstrap

Run the main bootstrap script from inside the repo:

```bash
./scripts/bootstrap.sh
```

The script tries to:

- detect the platform
- install packages with the native package manager when available
- install core CLI tools including `bat`, `btop`, `delta`, `direnv`, `fd`, `jq`, `lazygit`, `neovim`, and `ripgrep`
- install VS Code where supported by the platform package manager or `snap`
- fall back to upstream installers for `starship`, `mise`, and `opencode` when needed
- set the global Git default branch to `main`
- auto-try setting Zsh as the default shell
- apply the Stow packages
- install TPM into `~/.local/share/tmux/plugins/tpm`
- install declared tmux plugins non-interactively
- run `mise install`
- print a final report instead of exiting on the first failure

### Platform behavior

- macOS: uses Homebrew, installs `ghostty` and VS Code as casks, and taps `anomalyco/tap` for `opencode`
- Ubuntu/Debian: uses `apt`, installs `ghostty` via `snap` when `snap` is available, installs Linux `code` via `snap` outside WSL, then falls back to official installers for tools not available in the default repos
- Arch: uses `pacman`
- WSL: use Ubuntu or Arch inside WSL, then run `./scripts/bootstrap.sh` inside the distro

## Linux prerequisites

Before running the bootstrap on Linux or inside WSL:

- sign in as your normal user, not `root`
- make sure that user can run `sudo`
- refresh package metadata and optionally bring the base system up to date
- install `git` if the distro image does not already include it

Ubuntu or Debian:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git sudo
sudo -v
```

Arch:

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git sudo
sudo -v
```

If you are provisioning a brand new non-WSL Linux machine and still need to create your user, do that first, add the user to the appropriate admin group, then sign back in as that user before running the dotfiles bootstrap.

## Ubuntu setup

Standalone Ubuntu or Debian:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

## Windows + WSL setup

Ubuntu in WSL, from an elevated PowerShell session on Windows:

```powershell
wsl --install -d Ubuntu
winget install --id Microsoft.VisualStudioCode -e
code --install-extension ms-vscode-remote.remote-wsl
```

After Ubuntu finishes installing:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

If WSL is already installed, you can list distros with:

```powershell
wsl -l -v
```

Inside WSL, the bootstrap installs the Unix toolchain and still attempts `ghostty` via `snap`, but it skips Linux VS Code so the Windows install can be used with Remote - WSL.

## Arch setup

Standalone Arch:

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Arch in WSL:

```powershell
winget install --id Microsoft.VisualStudioCode -e
code --install-extension ms-vscode-remote.remote-wsl
```

Then inside the Arch WSL distro:

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

On Arch in WSL, the bootstrap installs Linux `code` because the Arch path uses `pacman` directly; if you prefer the Windows VS Code client only, skip launching the Linux `code` binary and use Remote - WSL from the Windows install.

## Manual Stow usage

From the repo root:

```bash
stow --target="$HOME" zsh starship mise ghostty opencode tmux
```

To remove a package:

```bash
stow --target="$HOME" -D ghostty
```

To restow after edits:

```bash
stow --target="$HOME" --restow zsh starship mise ghostty opencode tmux
```

## Fresh machine flow

1. Clone the repo to `~/dotfiles`.
2. Run `./scripts/bootstrap.sh`.
3. Open a new shell.
4. Verify `zsh --version`, `bat --version`, `btop --version`, `delta --version`, `direnv version`, `fd --version`, `jq --version`, `lazygit --version`, `nvim --version`, `rg --version`, `starship --version`, `mise --version`, `opencode --version`, and `tmux -V`.
5. Run `mise install` again manually if you change `mise/.config/mise/config.toml` later.

## Notes

- The Zsh config guards tool initialization so a partial install still opens a working shell.
- `ghostty`, `code`, and `opencode` are best-effort installs. The bootstrap reports any skipped or failed steps at the end.
- On Debian/Ubuntu systems where the package exposes `batcat` instead of `bat`, the Zsh config aliases `bat` to `batcat`.
- On Debian/Ubuntu systems where the package exposes `fdfind` instead of `fd`, the Zsh config aliases `fd` to `fdfind`.
- `tmux` uses `tmux-256color` when available, falls back to `screen-256color`, and enables mouse support for scrolling and pane clicks.
- `tmux` uses TPM with `TMUX_PLUGIN_MANAGER_PATH` set to `~/.local/share/tmux/plugins/`.
- The bootstrap installs TPM and the declared tmux plugins automatically, so `prefix + I` is not required on a fresh setup.
