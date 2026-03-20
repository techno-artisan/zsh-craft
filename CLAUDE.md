# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Does

This is a shell setup installer ("zshcraft") that bootstraps a new Linux/macOS/Windows (Cygwin/MinGW) server or workstation with:
- **zsh** + **Oh My ZSH!** + **Powerlevel10k** theme
- **colorls** — colorized `ls` output (requires ruby-full)
- ZSH plugins: autosuggestions, syntax-highlighting, alias-finder, git, python, pip, docker, sudo
- Pre-configured `.zshrc`, `.p10k.zsh`, `.aliases`, `.functions`, `.colors` copied to `$HOME`

## Running the Installer

```bash
./install.sh
```

Requirements: bash >= 4, curl, git, sudo access, an internet connection.
The script ends by exec'ing into `zsh` with beautiful powerlevel10k theme.

## Architecture

### Entry Point: `install.sh`

The installer sources two files from `include/` at the top before doing anything:
- `include/.colors` — ANSI escape code variables (e.g. `FG_GREEN`, `FONT_BOLD`, `RESET_ALL`)
- `include/.functions` — all utility functions used during install

Install flow:
1. Print banner with `ZSHCRAFT_VERSION`
2. Validate bash version (`ensureValidBashVersion`)
3. Check sudo access — abort with error message if not available
4. Install prerequisites via apt: `ruby-full`, `zsh`
5. Install `colorls` via `sudo gem install colorls`
6. Install Oh My ZSH (unattended, `RUNZSH=no` to prevent auto-launch)
7. Install Powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting via `git clone`
8. Copy `home/.zshrc` and `home/.p10k.zsh` to `~`
9. Copy `include/.colors` → `~/.colors`
10. Combine `include/.functions` + `home/.functions.global` → `~/.functions`
11. Combine `home/.aliases.global` + OS/package-manager-specific alias files → `~/.aliases`
12. Replace `##ADDITIONAL_PLUGINS##` placeholder in `~/.zshrc` with any OS-specific plugins (e.g. `osx`)
13. `exec zsh -l`

### `include/.functions` — Installer Utilities

Key functions:
- `detectOS` — sets `$OS_TYPE` to `linux | osx | cygwin | mingw`
- `detectPackageManager` — sets `$PKMGR` to `apk | yum | apt | pacman | false` (priority order)
- `isPi` / `getHardwareRevision` — detects Raspberry Pi via `/proc/cpuinfo`
- `colorize` / `printc` / `printcLn` — colored terminal output using short color codes (`"wh"`, `"lyl"`, `"lre"`, etc.)
- `checkResult` / `checkResultLn` — prints green "successful" or red "FAILED" based on exit code
- `implode` — joins array elements with a delimiter (used for plugin list assembly)
- `ensureValidBashVersion` — exits with error if bash < `$MIN_BASH_VERSION`

### Alias/Config Files Copied to `~`

| Source                                                        | Destination                | When                 |
|---------------------------------------------------------------|----------------------------|----------------------|
| `home/.aliases.global`                                        | `~/.aliases` (base)        | always               |
| `home/package-manager-specific/.alias_{apk,apt,yum,pacman}`   | appended to `~/.aliases`   | linux only           |
| `home/arch-specific/.aliases.pi`                              | appended to `~/.aliases`   | linux + Raspberry Pi |
| `home/arch-specific/.aliases.osx`                             | appended to `~/.aliases`   | macOS only           |
| `home/arch-specific/.aliases.cygwin_mingw`                    | appended to `~/.aliases`   | Cygwin/MinGW only    |
| `home/.functions.global`                                      | appended to `~/.functions` | always               |
| `include/.functions`                                          | `~/.functions` (base)      | always               |
| `include/.colors`                                             | `~/.colors`                | always               |

### `##ADDITIONAL_PLUGINS##` Placeholder

`home/.zshrc` contains the literal string `##ADDITIONAL_PLUGINS##` inside the `plugins=(...)` block. The installer replaces it with OS-specific plugin names (currently only `osx` on macOS) using `sed -i`.
