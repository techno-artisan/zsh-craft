#!/usr/bin/env bash
# shellcheck disable=SC1090

# the installer version
# load essential include files
source ./include/.version
source ./include/.colors
source ./include/.functions

# configuration
# shellcheck disable=SC2034
MIN_BASH_VERSION="4"

# parse command line arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "zshcraft - The smart zsh installer [${ZSHCRAFT_VERSION}]"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --help, -h          Show this help message"
            echo "  --dry-run           Show what would be done without making changes"
            echo ""
            echo "Requirements:"
            echo "  - bash >= ${MIN_BASH_VERSION}"
            echo "  - curl, git"
            echo "  - sudo access (unless running as root)"
            echo "  - internet connection"
            echo ""
            echo "Supported platforms:"
            echo "  - Linux (Debian/Ubuntu-based with apt)"
            echo "  - macOS (manual prerequisite installation)"
            echo "  - Windows (Cygwin/MinGW)"
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN MODE - No changes will be made"
    echo ""
fi

clear

printcLn "zshcraft - The smart zsh installer [${ZSHCRAFT_VERSION}]" "wh"
echo

ensureValidBashVersion

# check for required tools
printcLn "checking for required tools..." "yl"
for tool in curl git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printcLn "ERROR: $tool is required but not found. Please install it first." "lre"
        exit 1
    fi
done
printcLn "all required tools found" "gr"

printcLn "ensure user has 'sudo' rights..." "yl"
if [[ $EUID -ne 0 ]] && ! sudo -v 2>/dev/null; then
    printcLn "ERROR: sudo access required. Ask an admin to add you to sudoers first." "lre";
    exit 1
fi

# Set SUDO_CMD based on whether we're running as root
if [[ $EUID -eq 0 ]]; then
    SUDO_CMD=""
    printcLn "running as root - elevated privileges available" "gr"
else
    SUDO_CMD="sudo"
fi

printcLn "installing prerequisites..." "wh"
printc "installing ruby-full and zsh via apt..." "lyl"
$SUDO_CMD apt install -y ruby-full zsh
checkResultLn "$?" || { printcLn "FAILED: package installation failed (check permissions or package manager)" "lre"; exit 1; }

printc "installing colorls via gem..." "lyl"
$SUDO_CMD gem install colorls
checkResultLn "$?" || { printcLn "FAILED: gem install colorls" "lre"; exit 1; }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# install "Oh My Zsh!"
# URL:    https://ohmyz.sh/
# github: https://github.com/ohmyzsh/ohmyzsh/
INSTALL_APP="Oh My ZSH!"
printcLn "installing '${INSTALL_APP}'..." "wh"
RUNZSH=no sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
RESULT=$?
printc "\ninstallation of ${INSTALL_APP} completed..." "wh"
checkResultLn "${RESULT}" || { printcLn "FAILED: ${INSTALL_APP}" "lre"; exit 1; }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# install Powerlevel10k
# github: https://github.com/romkatv/powerlevel10k
INSTALL_APP="Powerlevel10k"
printcLn "installing '${INSTALL_APP}'..." "wh"
# shellcheck disable=SC2086
git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
RESULT=$?
printc "installation of ${INSTALL_APP} completed..." "wh"
checkResultLn "${RESULT}" || { printcLn "FAILED: ${INSTALL_APP}" "lre"; exit 1; }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# install smart plugins for omz
INSTALL_APP="autosuggestions"
printcLn "installing '${INSTALL_APP}'..." "wh"
# shellcheck disable=SC2086
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
RESULT=$?
printc "installation of ${INSTALL_APP} completed..." "wh"
checkResultLn "${RESULT}" || { printcLn "FAILED: ${INSTALL_APP}" "lre"; exit 1; }

INSTALL_APP="syntax-highlighting"
printcLn "installing '${INSTALL_APP}'..." "wh"
# shellcheck disable=SC2086
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
RESULT=$?
printc "installation of ${INSTALL_APP} completed..." "wh"
checkResultLn "${RESULT}" || { printcLn "FAILED: ${INSTALL_APP}" "lre"; exit 1; }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# copy pre-configured oh-my-zsh + Powerlevel10k config file
printcLn "copying pre-configured config files..." "wh"
printc "...'.zshrc'..." "lyl"
cp ./home/.zshrc ~/.zshrc
checkResult "$?"
echo
printcLn "Powerlevel10k theme configuration:" "wh"
printcLn "  [1] Use pre-configured theme (recommended)" "lgr"
printcLn "  [2] Configure it yourself on first zsh start" "lyl"
echo
P10K_CHOICE=""
while [[ "$P10K_CHOICE" != "1" && "$P10K_CHOICE" != "2" ]]; do
    printc "Your choice [1]: " "lcy"
    read -r P10K_CHOICE
    P10K_CHOICE="${P10K_CHOICE:-1}"
done
if [[ "$P10K_CHOICE" == "1" ]]; then
    printc "copying pre-configured '.p10k.zsh'..." "lyl"
    cp ./home/.p10k.zsh ~/.p10k.zsh
    checkResultLn "$?"
else
    printcLn "skipping '.p10k.zsh' — Powerlevel10k will guide you through configuration on first start." "lyl"
fi
ADDITIONAL_PLUGINS=()

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# copy colors
# shellcheck disable=SC2088
COLORS_FILE=~/.colors

printcLn "copying colors file..." "lyl"

printc "main..." "lbl"
cp ./include/.colors "${COLORS_FILE}"
checkResultLn "$?"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# combine and copy functions
FUNCTIONS_FILE=~/.functions

printcLn "copying and combining functions files..." "lyl"

printc "main..." "lbl"
cp ./include/.functions "${FUNCTIONS_FILE}"
checkResult "$?"

printc "global..." "lbl"
cat ./home/.functions.global >> "${FUNCTIONS_FILE}"
checkResultLn "$?"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# combine and copy aliases
detectOS

# copy aliases
ALIASES_FILE=~/.aliases

printcLn "copying and combining aliases files..." "lyl"

# copy global
printc "global..." "lbl"
cp ./home/.aliases.global "${ALIASES_FILE}"
checkResult "$?"

# add OS type specific aliases
printc "os type/package manager specific..." "lbl"
case "${OS_TYPE}" in
    linux )
      # detect package manager
      detectPackageManager

      # add package manager specific aliases
      if [ "$PKMGR" != false ]; then
        cat ./home/package-manager-specific/.alias_"${PKMGR}" >> "${ALIASES_FILE}"
        checkResult "$?"
      else
        printc "undefined package manager?!? {aborting}" "lre"
        exit 255
      fi

      # (optional) add PI specific aliases
      isPi
      if [ "${IS_PI}" = true ]; then
        printc "PI detected..." "lbl"
        cat ./home/arch-specific/.aliases.pi >> "${ALIASES_FILE}"
        checkResult "$?"
      fi
      ;;
    osx )
      # add OSX specific aliases
      printc "OSX detected..." "lbl"
      cat ./home/arch-specific/.aliases.osx >> "${ALIASES_FILE}"
      checkResult "$?"
      ADDITIONAL_PLUGINS+=( osx )
      ;;
    cygwin | mingw )
      # add cygwin/mingw specific aliases
      printc "cygwin/mingw detected..." "lbl"
      cat ./home/arch-specific/.aliases.cygwin_mingw >> "${ALIASES_FILE}"
      checkResult "$?"
      ;;
esac

echo

# add additional oh my zsh plugins to '.zshrc'
if [ "${#ADDITIONAL_PLUGINS[@]}" -gt 0 ]; then
  printc "adding (optional) additional plugin to '.zshrc'..."
  JOINED_PLUGINS=$(implode " " "${ADDITIONAL_PLUGINS[@]}")
  sed -i "s/##ADDITIONAL_PLUGINS##/${JOINED_PLUGINS}/g" ~/.zshrc
  checkResult "$?"
else
  printc "cleaning up '.zshrc' from (unused) placeholders..."
  sed -i "s/##ADDITIONAL_PLUGINS##//g" ~/.zshrc
  checkResult "$?"
fi
echo

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# start zsh
printcLn "now finally starting the 'zsh' with fancy 'Oh My ZSH!' + P10k..." "ma"
echo

exec zsh -l
