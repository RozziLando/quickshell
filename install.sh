#!/usr/bin/env bash
# Quickshell island: dependencies (Arch and Fedora).
#
# What it does:
#   1. detects Arch or Fedora and installs the dependencies (pacman --needed,
#      dnf install: packages already installed are skipped)
#   2. asks whether VS Code should follow the shell theme; if yes it installs
#      the VS Code themes and the sync extension (scripts/vscode.sh)
# Nothing else: config folder, theme.json, keybinds and autostart are left
# as they are.
#
#   ./install.sh -y             accept the defaults, ask nothing
#   ./install.sh --no-packages  skip the package installation
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd -P)

YES=0
PACKAGES_STEP=1
for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --no-packages) PACKAGES_STEP=0 ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg (see ./install.sh --help)"; exit 1 ;;
    esac
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*"; }

# ask_yn "question" default(true/false) -> prints true/false
ask_yn() {
    local q=$1 def=$2 hint r
    if [ "$YES" = 1 ]; then echo "$def"; return; fi
    if [ "$def" = true ]; then hint="Y/n"; else hint="y/N"; fi
    read -r -p "    $q [$hint] " r
    case "$r" in
        [yY]*) echo true ;;
        [nN]*) echo false ;;
        *) echo "$def" ;;
    esac
}

# ---------- Checks ----------
if [ "$(id -u)" -eq 0 ]; then
    echo "Run it as your normal user (not with sudo): it asks for the password when needed."
    exit 1
fi

DISTRO=""
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
        *" arch "*) DISTRO=arch ;;
        *" fedora "*) DISTRO=fedora ;;
    esac
fi
if [ -z "$DISTRO" ] && [ "$PACKAGES_STEP" = 1 ]; then
    echo "Unsupported distribution: only Arch Linux and Fedora (and their derivatives) are supported."
    exit 1
fi

# ---------- 1. Dependencies ----------
ARCH_PACKAGES=(
    quickshell hyprland                 # shell (>= 0.3) and compositor
    awww                                # wallpaper with transitions
    networkmanager                      # Wi-Fi and network
    bluez bluez-utils                   # Bluetooth
    pipewire pipewire-pulse wireplumber libpulse   # audio; pactl for the headphone jack
    brightnessctl upower                # brightness, battery
    playerctl                           # media keys
    grim slurp wl-clipboard             # screenshots, lock screen background
    libnotify                           # notify-send
    glib2                               # gdbus (logind signals: sleep, lock)
    diffutils                           # cmp (login screen copy)
    qt6-imageformats                    # .webp wallpapers
    inter-font noto-fonts-emoji noto-fonts-cjk     # fonts, emoji, CJK
)
FEDORA_PACKAGES=(
    quickshell hyprland swaybg NetworkManager bluez
    pipewire pipewire-pulseaudio wireplumber pulseaudio-utils
    brightnessctl upower playerctl
    grim slurp wl-clipboard libnotify glib2 diffutils
    qt6-qtimageformats rsms-inter-fonts google-noto-color-emoji-fonts google-noto-sans-cjk-fonts
)

install_packages() {
    if [ "$DISTRO" = arch ]; then
        local opts=(--needed)
        [ "$YES" = 1 ] && opts+=(--noconfirm)
        sudo pacman -S "${opts[@]}" "$@"
    else
        local opts=()
        [ "$YES" = 1 ] && opts+=(-y)
        sudo dnf install "${opts[@]}" "$@"
    fi
}

if [ "$PACKAGES_STEP" = 1 ]; then
    if [ "$DISTRO" = arch ]; then
        say "Arch Linux detected: installing dependencies (pacman --needed, installed ones are skipped)"
        install_packages "${ARCH_PACKAGES[@]}"
    else
        say "Fedora detected: installing dependencies (installed ones are skipped)"
        # Hyprland and Quickshell >= 0.3 come from COPR repositories
        if ! dnf copr --help >/dev/null 2>&1; then
            sudo dnf install -y 'dnf-command(copr)'
        fi
        sudo dnf copr enable -y errornointernet/quickshell
        sudo dnf copr enable -y solopasha/hyprland
        install_packages "${FEDORA_PACKAGES[@]}"
    fi
else
    say "Skipping packages (--no-packages)"
fi

# ---------- 2. VS Code themes (optional) ----------
# The VS Code theme follows the shell one (vscode/ and scripts/vscode.sh)
say "VS Code themes"
VSCODE_BIN=""
for c in code codium code-oss; do
    if command -v "$c" >/dev/null 2>&1; then VSCODE_BIN=$c; break; fi
done
if [ -z "$VSCODE_BIN" ]; then
    info "VS Code not found (code, codium or code-oss): skipped"
elif [ "$(ask_yn "Install the VS Code extensions so VS Code follows the shell theme?" false)" = true ]; then
    sh "$SRC/scripts/vscode.sh" || warn "VS Code themes: something went wrong (see above)"
else
    info "skipped (run scripts/vscode.sh later to add it)"
fi

say "Done."
