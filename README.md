# Dotfiles

## Getting started

Use the steps for your OS, then run the bootstrap:

```bash
./scripts/bootstrap.sh
```

The bootstrap:

- installs a small native bootstrap set including `curl`, `git`, `stow`, `zsh`, and `tmux`
- installs `mise` with the official installer and verifies the binary before using it later in the script
- installs most CLIs and runtimes with `mise`, including `bat`, `btop`, `delta`, `direnv`, `eza`, `fd`, `fzf`, `jq`, `lazygit`, `neovim`, `opencode`, `ripgrep`, `starship`, `uv`, `zoxide`, `pi-agent`, and `agent-browser`
- installs GUI apps with the best available OS-specific path, including `ghostty` and VS Code where supported
- sets the global Git default branch to `main`
- tries to set Zsh as the default shell
- applies the Stow packages
- installs TPM into `~/.local/share/tmux/plugins/tpm`
- installs declared tmux plugins non-interactively
- runs `mise install --raw`
- streams command output live so package manager and bootstrap logs are visible while it runs

## macOS

Use your normal user account, not `root`.

Install Homebrew first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew --version
```

If `brew --version` fails on Intel macOS, use:

```bash
eval "$(/usr/local/bin/brew shellenv)"
brew --version
```

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

- Ubuntu installs the native bootstrap packages with `apt`
- outside WSL, Ubuntu installs `snapd` if needed and uses `snap` for VS Code and Ghostty
- most CLI tools and runtimes come from `mise`, not `apt`

## Arch Linux

Use a normal user with `sudo` access.

If you are on a fresh Arch install and still need to create a user, do that first, add the user to `wheel`, enable `sudo` for `wheel`, then sign back in as that user.

Example user and sudo setup on a fresh Arch install:

```bash
useradd -m -G wheel -s /bin/bash <username>
passwd <username>
EDITOR=vi visudo
```

Then uncomment this line in `visudo`:

```text
%wheel ALL=(ALL:ALL) ALL
```

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

Notes:

- Arch installs the native bootstrap packages and GUI apps with `pacman`
- most CLI tools and runtimes come from `mise`, not `pacman`

## Fedora

Use a normal user with `sudo` access.

Initial setup:

```bash
sudo dnf upgrade -y
sudo dnf install -y git sudo
sudo -v
```

Then bootstrap:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Notes:

- Fedora installs the native bootstrap packages with `dnf`
- VS Code uses the official Microsoft RPM repository
- Ghostty uses the Fedora COPR published by `scottames/ghostty`
- most CLI tools and runtimes come from `mise`, not `dnf`

## Windows + WSL

### Ubuntu in WSL

From an elevated PowerShell session on Windows:

```powershell
wsl --install -d Ubuntu
winget install --id Microsoft.VisualStudioCode -e
code --install-extension ms-vscode-remote.remote-wsl
wsl -l -v
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

Inside WSL, the bootstrap skips Linux GUI app installs so the Windows install can be used with Remote - WSL.

### Arch in WSL

From Windows:

```powershell
winget install --id Microsoft.VisualStudioCode -e
code --install-extension ms-vscode-remote.remote-wsl
wsl -l -v
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

On Arch in WSL, the bootstrap also skips Linux GUI app installs so the Windows VS Code client can be used with Remote - WSL.

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
pi --version
tmux -V
git config --global --get init.defaultBranch
```

Expected Git default branch output:

```text
main
```

## Notes

- `ghostty` and `code` are best-effort OS-specific installs; bootstrap reports skipped or failed steps at the end
- `mise` is installed with the official installer and prefers `/usr/local/bin/mise`; if that is not writable it falls back to `~/.local/bin/mise`
- `mise install --raw` manages almost all non-GUI userland tools in this repo, and any failures are listed at the end of the bootstrap report with the attempted command output
- native package manager commands now stream their logs live during bootstrap instead of buffering output until the end
- `tmux` uses `tmux-256color` when available, falls back to `screen-256color`, and enables mouse support for scrolling and pane clicks
- `tmux` uses TPM with `TMUX_PLUGIN_MANAGER_PATH` set to `~/.local/share/tmux/plugins/`
- bootstrap installs TPM and the declared tmux plugins automatically, so `prefix + I` is not required on a fresh setup
