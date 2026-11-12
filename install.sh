#!/usr/bin/env bash
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd -P)

YES=0
PACKAGES_STEP=1
for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --no-packages) PACKAGES_STEP=0 ;;
        -h|--help)
            printf '%s\n' \
                "Quickshell island: dependencies (Arch and Fedora)." \
                "" \
                "  1. detects Arch or Fedora and installs the dependencies" \
                "  2. turns on FastConnectable in /etc/bluetooth/main.conf" \
                "  3. asks whether VS Code should follow the shell theme (scripts/vscode.sh)" \
                "" \
                "  ./install.sh -y             accept the defaults, ask nothing" \
                "  ./install.sh --no-packages  skip the package installation"
            exit 0 ;;
        *) echo "Unknown option: $arg (see ./install.sh --help)"; exit 1 ;;
    esac
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*"; }

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

if [ "$(id -u)" -eq 0 ]; then
    echo "Run it as your normal user (not with sudo): it asks for the password when needed."
    exit 1
fi

DISTRO=""
if [ -r /etc/os-release ]; then
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

ARCH_PACKAGES=(
    quickshell hyprland
    awww
    networkmanager
    bluez bluez-utils
    pipewire pipewire-pulse wireplumber libpulse
    brightnessctl upower
    playerctl
    grim slurp wl-clipboard
    libnotify
    glib2
    diffutils
    qt6-imageformats
    inter-font noto-fonts-emoji noto-fonts-cjk
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

BT_CONF=${BT_CONF:-/etc/bluetooth/main.conf}
if [ -f "$BT_CONF" ]; then
    say "Bluetooth"
    if grep -Eq '^[[:space:]]*FastConnectable[[:space:]]*=[[:space:]]*true' "$BT_CONF"; then
        info "FastConnectable already on"
    else
        if [ -w "$BT_CONF" ] && [ -w "$(dirname "$BT_CONF")" ]; then AS_ROOT=""; else AS_ROOT=sudo; fi
        [ -e "$BT_CONF.bak-quickshell" ] || $AS_ROOT cp "$BT_CONF" "$BT_CONF.bak-quickshell"
        if grep -Eq '^[[:space:]]*#?[[:space:]]*FastConnectable[[:space:]]*=' "$BT_CONF"; then
            $AS_ROOT sed -i -E '0,/^[[:space:]]*#?[[:space:]]*FastConnectable[[:space:]]*=.*/s//FastConnectable = true/' "$BT_CONF"
        elif grep -q '^\[General\]' "$BT_CONF"; then
            $AS_ROOT sed -i '0,/^\[General\]/s//[General]\nFastConnectable = true/' "$BT_CONF"
        else
            printf '\n[General]\nFastConnectable = true\n' | $AS_ROOT tee -a "$BT_CONF" >/dev/null
        fi
        info "FastConnectable = true in $BT_CONF (old file: $BT_CONF.bak-quickshell)"
        info "known devices reconnect faster; applied at the next boot or with: sudo systemctl restart bluetooth"
    fi
fi

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
