# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Does

**zshcraft** (v1.1.0) is a shell setup installer that bootstraps a new Linux/macOS/Windows (Cygwin/MinGW) server or workstation with:
- **zsh** + **Oh My ZSH!** + **Powerlevel10k** theme
- **colorls** — colorized `ls` output (requires ruby-full)
- ZSH plugins: autosuggestions, syntax-highlighting, alias-finder, git, python, pip, docker, sudo
- Pre-configured dotfiles copied to `$HOME`: `.zshrc`, `.p10k.zsh`, `.aliases`, `.functions`, `.colors`
- Adds `$HOME/scripts` to `$PATH` (via `.zshrc`)

## Scripts

### `install.sh` — Installer

Non-interactive. Sources `include/.version`, `include/.colors`, `include/.functions` at the top.

**Requirements:** bash >= 4, `curl`, `git`, `sudo` access, internet connection.

Install flow:
1. Print banner with `$ZSHCRAFT_VERSION`
2. Validate bash version (`ensureValidBashVersion`)
3. Check sudo access — abort if not available
4. Install prerequisites via apt: `ruby-full`, `zsh`
5. Install `colorls` via `sudo gem install colorls`
6. Install Oh My ZSH (unattended, `RUNZSH=no`)
7. Clone Powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting into `~/.oh-my-zsh/custom/`
8. Copy `home/.zshrc` and `home/.p10k.zsh` to `~`
9. Copy `include/.colors` → `~/.colors`
10. Combine `include/.functions` + `home/.functions.global` → `~/.functions`
11. Combine `home/.aliases.global` + OS/package-manager-specific alias files → `~/.aliases`
12. Replace `##ADDITIONAL_PLUGINS##` placeholder in `~/.zshrc` with OS-specific plugins (e.g. `osx`) — or remove it if unused
13. `exec zsh -l`

> **Known issue:** `home/.zshrc` currently does not contain the `##ADDITIONAL_PLUGINS##` placeholder, so the macOS `osx` plugin injection (step 12) has no effect. The `sed` command runs silently without error.

### `uninstall.sh` — Uninstaller

Fully interactive. Supports `--dry-run` flag (preview without changes). Sources the same three include files.

Proceeds in groups — each can be skipped independently:
- **Group 1** — Dotfiles (`~/.zshrc`, `.p10k.zsh`, `.aliases`, `.functions`, `.colors`): remove / backup+remove / skip
- **Group 1b** — ZSH residual files: `~/.zsh_history`, `~/.shell.pre-oh-my-zsh`, `.zcompdump*`, p10k cache files/dirs — scanned first, then a single yes/no prompt
- **Group 2** — `~/.oh-my-zsh/` (includes Powerlevel10k + custom plugins): yes/no prompt
- **Group 3** — Restore login shell to `/bin/bash` via `chsh` — only shown if current shell is zsh; runs before package removal so zsh is still available for `chsh`
- **Group 4** — Packages (`colorls`, `zsh`, `ruby-full`): per-package prompts; pre-existing packages (installed before zshcraft) are flagged with a warning

## Repository Structure

```
install.sh                          # installer entry point
uninstall.sh                        # uninstaller entry point
include/
  .version                          # ZSHCRAFT_VERSION variable (e.g. "1.1.0")
  .colors                           # ANSI escape code variables
  .functions                        # installer utility functions
home/
  .zshrc                            # base zsh config (theme, plugins, sources)
  .p10k.zsh                         # Powerlevel10k theme config
  .aliases.global                   # global aliases (always copied)
  .functions.global                 # global functions appended to ~/.functions
  arch-specific/
    .aliases.osx                    # macOS aliases
    .aliases.pi                     # Raspberry Pi aliases
    .aliases.cygwin_mingw           # Cygwin/MinGW aliases
  package-manager-specific/
    .alias_apt / .alias_apk / .alias_yum / .alias_pacman
assets/                             # screenshots for README
```

## `include/.functions` — Installer Utilities

Key functions:
- `detectOS` — sets `$OS_TYPE` to `linux | osx | cygwin | mingw`
- `detectPackageManager` — sets `$PKMGR` to `apk | yum | apt | pacman | false` (detection priority in this order)
- `isPi` / `getHardwareRevision` / `getPiModel` — Raspberry Pi detection via `/proc/cpuinfo`
- `colorize` / `printc` / `printcLn` — colored terminal output using short color codes
- `checkResult` / `checkResultLn` — prints green "successful" or red "FAILED" based on exit code
- `implode` — joins array elements with a delimiter (used for plugin list assembly)
- `ensureValidBashVersion` — exits with error if bash < `$MIN_BASH_VERSION`
- `versionCompare` — compares two semver strings, returns 0 (equal), 1 (v1>v2), 2 (v1<v2)

### Color Code Reference (`colorize` / `printc`)

Short codes used throughout installer output:

| Code  | Color         | Code  | Color          |
|-------|---------------|-------|----------------|
| `wh`  | white         | `ma`  | magenta        |
| `rd`  | red           | `cy`  | cyan           |
| `gr`  | green         | `bl`  | black          |
| `ye`  | yellow        | `lgy` | light gray     |
| `yl`  | **blue** (!)  | `dgy` | dark gray      |
| `lre` | light red     | `lbl` | light blue     |
| `lgr` | light green   | `lyl` | light yellow   |
| `lma` | light magenta | `lcy` | light cyan     |

> **Note:** `"yl"` maps to **blue** (not yellow) — `"ye"` is yellow. This is a quirk of the existing color code naming.

## Alias/Config Files Copied to `~`

| Source                                                       | Destination                | When                    |
|--------------------------------------------------------------|----------------------------|-------------------------|
| `home/.aliases.global`                                       | `~/.aliases` (base)        | always                  |
| `home/package-manager-specific/.alias_{apk,apt,yum,pacman}` | appended to `~/.aliases`   | linux only              |
| `home/arch-specific/.aliases.pi`                             | appended to `~/.aliases`   | linux + Raspberry Pi    |
| `home/arch-specific/.aliases.osx`                            | appended to `~/.aliases`   | macOS only              |
| `home/arch-specific/.aliases.cygwin_mingw`                   | appended to `~/.aliases`   | Cygwin/MinGW only       |
| `include/.functions`                                         | `~/.functions` (base)      | always                  |
| `home/.functions.global`                                     | appended to `~/.functions` | always                  |
| `include/.colors`                                            | `~/.colors`                | always                  |

## `home/.functions.global` — User-facing Functions

- `rdu [path...] [N]` — recursive disk usage sorted descending by size, limited to N entries (default 50)

## `##ADDITIONAL_PLUGINS##` Placeholder

`home/.zshrc` is intended to contain the literal string `##ADDITIONAL_PLUGINS##` inside the `plugins=(...)` block. The installer replaces it with OS-specific plugin names (currently only `osx` on macOS) or removes it on all other platforms. Currently this placeholder is missing from `home/.zshrc` — see Known Issues above.

## Supported Platforms

| Platform | Package managers           | Notes                                    |
|----------|----------------------------|------------------------------------------|
| Linux    | APT, YUM, APK, Pacman      | Tested on Debian/Ubuntu                  |
| macOS    | — (manual prereqs)         | `osx` plugin injection currently broken  |
| Windows  | Cygwin / MinGW             | Manual prereq installation required      |

> Prerequisite installation (`zsh`, `ruby-full`, `colorls` via `apt`/`gem`) only works on Debian/Ubuntu-based systems. On other platforms, install these manually before running.
