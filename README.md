# Dotfiles

## Getting started

Use the steps for your OS, then run the bootstrap:

```bash
./scripts/bootstrap.sh
```

The bootstrap:

- installs packages with the native package manager when available
- installs shell and navigation tools including `zsh`, `starship`, `zoxide`, `fzf`, and `direnv`
- installs editor, terminal, and session tools including `neovim`, `tmux`, `ghostty`, `opencode`, and VS Code where supported by the platform package manager or `snap`
- installs CLI utilities including `bat`, `btop`, `curl`, `delta`, `eza`, `fd`, `git`, `jq`, `lazygit`, `ripgrep`, `stow`, and `sudo` where the platform setup calls for it
- falls back to upstream installers for `starship`, `mise`, and `opencode` when needed
- installs runtime management with `mise`
- sets the global Git default branch to `main`
- tries to set Zsh as the default shell
- applies the Stow packages
- installs TPM into `~/.local/share/tmux/plugins/tpm`
- installs declared tmux plugins non-interactively
- runs `mise install`

## macOS

Prerequisites:

- install Homebrew first
- use your normal user account, not `root`

Setup:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

## Ubuntu or Debian

Use a normal user with `sudo` access.

If you are on a fresh machine and still need to create a user, do that first, add the user to the sudo-enabled admin group for the distro, then sign back in as that user.

Initial setup:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git sudo
sudo -v
```

Then bootstrap:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Notes:

- `ghostty` is installed via `snap` when `snap` is available
- outside WSL, Linux `code` is installed via `snap` when available
- on Debian/Ubuntu systems where the package exposes `batcat` instead of `bat`, the Zsh config aliases `bat` to `batcat`
- on Debian/Ubuntu systems where the package exposes `fdfind` instead of `fd`, the Zsh config aliases `fd` to `fdfind`

## Arch Linux

Use a normal user with `sudo` access.

If you are on a fresh Arch install and still need to create a user, do that first, add the user to `wheel`, enable `sudo` for `wheel`, then sign back in as that user.

Initial setup:

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git sudo
sudo -v
```

Then bootstrap:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

## Windows + WSL

### Ubuntu in WSL

From an elevated PowerShell session on Windows:

```powershell
wsl --install -d Ubuntu
winget install --id Microsoft.VisualStudioCode -e
code --install-extension ms-vscode-remote.remote-wsl
```

Then inside Ubuntu:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git sudo
sudo -v
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Inside WSL, the bootstrap still attempts `ghostty` via `snap`, but it skips Linux VS Code so the Windows install can be used with Remote - WSL.

### Arch in WSL

From Windows:

```powershell
winget install --id Microsoft.VisualStudioCode -e
code --install-extension ms-vscode-remote.remote-wsl
```

Then inside the Arch WSL distro:

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git sudo
sudo -v
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

On Arch in WSL, the bootstrap installs Linux `code` because the Arch path uses `pacman` directly. If you prefer the Windows VS Code client only, use Remote - WSL from the Windows install and ignore the Linux `code` binary.

## Verify

After bootstrap, open a new shell and verify:

```bash
zsh --version
bat --version
btop --version
delta --version
direnv version
fd --version
jq --version
lazygit --version
nvim --version
rg --version
starship --version
mise --version
opencode --version
tmux -V
git config --global --get init.defaultBranch
```

Expected Git default branch output:

```text
main
```

## Notes

- `ghostty`, `code`, and `opencode` are best-effort installs; bootstrap reports skipped or failed steps at the end
- `tmux` uses `tmux-256color` when available, falls back to `screen-256color`, and enables mouse support for scrolling and pane clicks
- `tmux` uses TPM with `TMUX_PLUGIN_MANAGER_PATH` set to `~/.local/share/tmux/plugins/`
- bootstrap installs TPM and the declared tmux plugins automatically, so `prefix + I` is not required on a fresh setup
