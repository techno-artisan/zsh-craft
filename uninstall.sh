#!/usr/bin/env bash
# shellcheck disable=SC1090

source ./include/.version
source ./include/.colors
source ./include/.functions

MIN_BASH_VERSION="4"
ensureValidBashVersion

# parse --dry-run flag
DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

clear

printcLn "zshcraft - Uninstaller [${ZSHCRAFT_VERSION}]" "wh"
if [ "$DRY_RUN" = true ]; then
  printcLn "[DRY RUN] No changes will be made." "lyl"
fi
echo

# ── Helpers ───────────────────────────────────────────────────────────────────

# prompt user: ask_user "Remove dotfiles?"
# returns 0 (yes) or 1 (no)
function ask_user() {
  local QUESTION=$1
  printc "${QUESTION} [y/N] " "lyl"
  read -r REPLY
  echo
  [[ "$REPLY" =~ ^[Yy]$ ]]
}

# run_or_dry "Description" command arg1 arg2 ...
# In live mode: runs the command and returns its exit code.
# In dry-run mode: prints [DRY RUN] description and returns 0.
function run_or_dry() {
  local DESC=$1
  shift
  if [ "$DRY_RUN" = true ]; then
    printcLn "[DRY RUN] ${DESC}" "lgy"
  else
    "$@"
  fi
}

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

function backup_file() {
  local FILE=$1
  if [ -f "${FILE}" ]; then
    run_or_dry "Backup ${FILE} -> ${FILE}.bak.${TIMESTAMP}" \
      cp "${FILE}" "${FILE}.bak.${TIMESTAMP}"
    [ "$DRY_RUN" = false ] && checkResult "$?"
  fi
}

# ── Group 1: Dotfiles ─────────────────────────────────────────────────────────
DOTFILES=(~/.zshrc ~/.p10k.zsh ~/.aliases ~/.functions ~/.colors)

printcLn "Group 1: Dotfiles" "wh"
printcLn "  ~/.zshrc  ~/.p10k.zsh  ~/.aliases  ~/.functions  ~/.colors" "lgy"
printcLn "  [1] remove only  [2] backup and remove  [3] skip" "lgy"
printc "  Choice [1/2/3]: " "lyl"
read -r DOTFILES_CHOICE
echo

case "$DOTFILES_CHOICE" in
  1)
    for f in "${DOTFILES[@]}"; do
      printc "  remove ${f}..." "lbl"
      run_or_dry "Remove ${f}" rm -f "${f}"
      [ "$DRY_RUN" = false ] && checkResult "$?"
    done
    ;;
  2)
    for f in "${DOTFILES[@]}"; do
      printc "  backup ${f}..." "lbl"
      backup_file "${f}"
      printc "  remove ${f}..." "lbl"
      run_or_dry "Remove ${f}" rm -f "${f}"
      [ "$DRY_RUN" = false ] && checkResult "$?"
    done
    ;;
  *)
    printcLn "  skipped." "dgy"
    ;;
esac
echo

# ── Group 1b: ZSH residual files ──────────────────────────────────────────────
printcLn "Group 1b: ZSH residual files" "wh"

# collect files that actually exist
RESIDUAL_FILES=()
RESIDUAL_DIRS=()
[ -f ~/.shell.pre-oh-my-zsh ] && RESIDUAL_FILES+=( ~/.shell.pre-oh-my-zsh )
[ -f ~/.zsh_history ]         && RESIDUAL_FILES+=( ~/.zsh_history )
# .zcompdump* files (may have hostname suffix and .zwc variant)
while IFS= read -r f; do
  RESIDUAL_FILES+=( "$f" )
done < <(find ~ -maxdepth 1 -name ".zcompdump*" 2>/dev/null)
# ~/.cache: p10k dump/prompt files (.zsh + .zwc) and gitstatus/p10k-<user> dirs
while IFS= read -r f; do
  RESIDUAL_FILES+=( "$f" )
done < <(find ~/.cache -maxdepth 1 \( -name "p10k-dump-*.zsh" -o -name "p10k-dump-*.zsh.zwc" -o -name "p10k-instant-prompt-*.zsh" -o -name "p10k-instant-prompt-*.zsh.zwc" \) 2>/dev/null)
while IFS= read -r d; do
  RESIDUAL_DIRS+=( "$d" )
done < <(find ~/.cache -maxdepth 1 -type d -name "p10k-*" 2>/dev/null)

if [ "${#RESIDUAL_FILES[@]}" -eq 0 ] && [ "${#RESIDUAL_DIRS[@]}" -eq 0 ]; then
  printcLn "  no residual files found — skipping." "dgy"
else
  printcLn "  the following residual files/dirs were found:" "lgy"
  for f in "${RESIDUAL_FILES[@]}"; do
    printcLn "    ${f}" "lgy"
  done
  for d in "${RESIDUAL_DIRS[@]}"; do
    printcLn "    ${d}/" "lgy"
  done
  echo
  if ask_user "Remove all residual files?"; then
    for f in "${RESIDUAL_FILES[@]}"; do
      printc "  remove ${f}..." "lbl"
      run_or_dry "Remove ${f}" rm -f "${f}"
      [ "$DRY_RUN" = false ] && checkResult "$?"
    done
    for d in "${RESIDUAL_DIRS[@]}"; do
      printc "  remove ${d}/..." "lbl"
      run_or_dry "Remove ${d}/" rm -rf "${d}"
      [ "$DRY_RUN" = false ] && checkResult "$?"
    done
  else
    printcLn "  skipped." "dgy"
  fi
fi
echo

# ── Group 2: Oh My ZSH + plugins ─────────────────────────────────────────────
printcLn "Group 2: Oh My ZSH + Powerlevel10k + plugins" "wh"
printcLn "  ~/.oh-my-zsh/ (includes themes and custom plugins)" "lgy"

if ask_user "Remove ~/.oh-my-zsh/?"; then
  printc "  removing ~/.oh-my-zsh/..." "lbl"
  run_or_dry "Remove ~/.oh-my-zsh/" rm -rf ~/.oh-my-zsh
  [ "$DRY_RUN" = false ] && checkResultLn "$?"
else
  printcLn "  skipped." "dgy"
fi
echo

# ── Group 3: Restore shell ────────────────────────────────────────────────────
# NOTE: must run BEFORE package removal — zsh must still exist when chsh runs
printcLn "Group 3: Restore default shell" "wh"
printcLn "  restores /bin/bash for the current user only" "lgy"

CURRENT_USER=$(whoami)
CURRENT_SHELL=$(grep "^${CURRENT_USER}:" /etc/passwd | cut -d: -f7)

if echo "${CURRENT_SHELL}" | grep -q "zsh"; then
  printcLn "  current shell for ${CURRENT_USER}: ${CURRENT_SHELL}" "lgy"
  if ask_user "Restore login shell to /bin/bash for ${CURRENT_USER}?"; then
    printc "  chsh ${CURRENT_USER}..." "lbl"
    run_or_dry "chsh -s /bin/bash ${CURRENT_USER}" chsh -s /bin/bash "${CURRENT_USER}"
    [ "$DRY_RUN" = false ] && checkResultLn "$?"
  else
    printcLn "  skipped." "dgy"
  fi
else
  printcLn "  ${CURRENT_USER} is not using zsh — skipping." "dgy"
fi
echo

# ── Group 4: Packages ─────────────────────────────────────────────────────────
printcLn "Group 4: Packages (colorls, zsh, ruby-full)" "wh"

# run checks upfront before asking the user anything
OMZ_DIR=~/.oh-my-zsh
OMZ_TIME=$(stat -c "%Y" "$OMZ_DIR" 2>/dev/null)

# colorls pre-existing check
COLORLS_GEM_PATH=$(gem contents colorls 2>/dev/null | head -1)
COLORLS_INSTALLED=false
COLORLS_PREEXISTING=false
if [ -n "$COLORLS_GEM_PATH" ] && [ -e "$COLORLS_GEM_PATH" ]; then
  COLORLS_INSTALLED=true
  if [ -n "$OMZ_TIME" ]; then
    COLORLS_TIME=$(stat -c "%Y" "$COLORLS_GEM_PATH" 2>/dev/null)
    [ -n "$COLORLS_TIME" ] && [ "$COLORLS_TIME" -lt "$OMZ_TIME" ] && COLORLS_PREEXISTING=true
  fi
fi

# ruby-full pre-existing check
RUBY_PATH=$(dpkg -L ruby-full 2>/dev/null | grep -m1 "^/usr/lib/ruby")
RUBY_INSTALLED=false
RUBY_PREEXISTING=false
if [ -n "$RUBY_PATH" ] && [ -e "$RUBY_PATH" ]; then
  RUBY_INSTALLED=true
  if [ -n "$OMZ_TIME" ]; then
    RUBY_TIME=$(stat -c "%Y" "$RUBY_PATH" 2>/dev/null)
    [ -n "$RUBY_TIME" ] && [ "$RUBY_TIME" -lt "$OMZ_TIME" ] && RUBY_PREEXISTING=true
  fi
fi

# zsh login-shell check
REMAINING_ZSH_USERS=$(grep "zsh" /etc/passwd 2>/dev/null | cut -d: -f1)

# display status overview
if [ "$COLORLS_INSTALLED" = true ]; then
  if [ "$COLORLS_PREEXISTING" = true ]; then
    printcLn "  colorls   — installed  [pre-existing, installed before zshcraft]" "lyl"
  else
    printcLn "  colorls   — installed  [installed by zshcraft]" "lgy"
  fi
else
  printcLn "  colorls   — not found" "dgy"
fi

if [ "$RUBY_INSTALLED" = true ]; then
  if [ "$RUBY_PREEXISTING" = true ]; then
    printcLn "  ruby-full — installed  [pre-existing, installed before zshcraft]" "lyl"
  else
    printcLn "  ruby-full — installed  [installed by zshcraft]" "lgy"
  fi
else
  printcLn "  ruby-full — not found" "dgy"
fi

if [ -n "$REMAINING_ZSH_USERS" ]; then
  printcLn "  zsh       — installed  [still login shell for: ${REMAINING_ZSH_USERS//$'\n'/, }]" "lyl"
else
  printcLn "  zsh       — installed  [no users using it as login shell]" "lgy"
fi
echo

# per-package prompts based on findings
printcLn "  requires sudo access" "lgy"

if [ "$DRY_RUN" = true ]; then
  [ "$COLORLS_INSTALLED" = true ] && [ "$COLORLS_PREEXISTING" = false ] && \
    run_or_dry "sudo gem uninstall colorls -ax" sudo gem uninstall colorls -ax
  [ "$COLORLS_PREEXISTING" = true ] && \
    printcLn "[DRY RUN] colorls pre-existing — would skip unless forced." "lgy"
  run_or_dry "sudo apt remove -y zsh/ruby-full (adjusted per selections at runtime)" sudo apt remove -y zsh
else
  if ! sudo -v 2>/dev/null; then
    printcLn "  ERROR: sudo access required — skipping package removal." "lre"
  else
    # colorls
    if [ "$COLORLS_INSTALLED" = true ]; then
      if [ "$COLORLS_PREEXISTING" = true ]; then
        printcLn "  colorls was installed before zshcraft." "lyl"
        if ask_user "  Remove colorls anyway?"; then
          printc "  uninstalling colorls via gem..." "lbl"
          sudo gem uninstall colorls -ax
          checkResult "$?"
        else
          printcLn "  colorls kept." "dgy"
        fi
      else
        if ask_user "  Remove colorls?"; then
          printc "  uninstalling colorls via gem..." "lbl"
          sudo gem uninstall colorls -ax
          checkResult "$?"
        else
          printcLn "  colorls kept." "dgy"
        fi
      fi
    fi

    # build apt package list
    APT_PKGS=()

    # zsh
    if [ -n "$REMAINING_ZSH_USERS" ]; then
      printcLn "  zsh is still the login shell for: ${REMAINING_ZSH_USERS//$'\n'/, }" "lyl"
      if ask_user "  Remove zsh anyway?"; then
        APT_PKGS+=( zsh )
      fi
    else
      if ask_user "  Remove zsh?"; then
        APT_PKGS+=( zsh )
      fi
    fi

    # ruby-full
    if [ "$RUBY_INSTALLED" = true ]; then
      if [ "$RUBY_PREEXISTING" = true ]; then
        printcLn "  ruby-full was installed before zshcraft." "lyl"
        if ask_user "  Remove ruby-full anyway?"; then
          APT_PKGS+=( ruby-full )
        else
          printcLn "  ruby-full kept." "dgy"
        fi
      else
        if ask_user "  Remove ruby-full?"; then
          APT_PKGS+=( ruby-full )
        else
          printcLn "  ruby-full kept." "dgy"
        fi
      fi
    fi

    if [ "${#APT_PKGS[@]}" -gt 0 ]; then
      printc "  removing ${APT_PKGS[*]} via apt..." "lbl"
      sudo apt remove -y "${APT_PKGS[@]}"
      checkResultLn "$?"
    fi
  fi
fi
echo

# ── Done ──────────────────────────────────────────────────────────────────────
printcLn "Uninstall complete." "lgr"
if [ "$DRY_RUN" = true ]; then
  printcLn "[DRY RUN] Nothing was changed." "lyl"
else
  if ps -p "$PPID" -o comm= 2>/dev/null | grep -q "zsh" || echo "$SHELL" | grep -q "zsh"; then
    if ask_user "You are currently in zsh. Switch to bash now?"; then
      exec bash -l
    fi
  fi
fi
echo
