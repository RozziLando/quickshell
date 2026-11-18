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
                "  2. makes Wi-Fi and Bluetooth work: firmware, drivers, NetworkManager and bluetooth services" \
                "  3. turns on FastConnectable in /etc/bluetooth/main.conf" \
                "  4. asks whether VS Code and its forks should follow the shell theme (scripts/vscode.sh)" \
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
    linux-firmware wireless-regdb
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
FEDORA_FIRMWARE=(
    linux-firmware iwlwifi-mvm-firmware iwlwifi-dvm-firmware realtek-firmware
    atheros-firmware brcmfmac-firmware mt7xxx-firmware
)
FEDORA_PACKAGES=(
    quickshell hyprland swaybg NetworkManager NetworkManager-wifi bluez wireless-regdb
    pipewire pipewire-pulseaudio wireplumber pulseaudio-utils
    brightnessctl upower playerctl
    grim slurp wl-clipboard libnotify glib2 diffutils
    qt6-qtimageformats rsms-inter-fonts google-noto-color-emoji-fonts google-noto-sans-cjk-fonts
)

SYS=${SYS:-/sys}

broadcom_wl_needed() {
    local d
    for d in "$SYS"/bus/pci/devices/*; do
        [ "$(cat "$d/vendor" 2>/dev/null)" = 0x14e4 ] || continue
        case "$(cat "$d/device" 2>/dev/null)" in
            0x43a0|0x43b1|0x4365) return 0 ;;
        esac
    done
    return 1
}

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
        if broadcom_wl_needed; then
            say "Broadcom Wi-Fi without an open driver: installing broadcom-wl-dkms"
            HEADERS=()
            for k in linux linux-lts linux-zen linux-hardened linux-rt; do
                pacman -Q "$k" >/dev/null 2>&1 && HEADERS+=("$k-headers")
            done
            install_packages broadcom-wl-dkms "${HEADERS[@]}" || warn "broadcom-wl-dkms could not be installed"
        fi
    else
        say "Fedora detected: installing dependencies (installed ones are skipped)"
        if ! dnf copr --help >/dev/null 2>&1; then
            sudo dnf install -y 'dnf-command(copr)'
        fi
        sudo dnf copr enable -y errornointernet/quickshell
        sudo dnf copr enable -y solopasha/hyprland
        install_packages "${FEDORA_PACKAGES[@]}"
        if dnf --version 2>/dev/null | grep -qi dnf5; then SKIP=(--skip-unavailable); else SKIP=(--setopt=strict=0); fi
        install_packages "${SKIP[@]}" "${FEDORA_FIRMWARE[@]}" || warn "some Wi-Fi/Bluetooth firmware packages could not be installed"
        if broadcom_wl_needed; then
            warn "Broadcom Wi-Fi without an open driver: install akmod-wl from RPM Fusion (nonfree) to use it"
        fi
    fi
else
    say "Skipping packages (--no-packages)"
fi

say "Wi-Fi and Bluetooth"
REBOOT_NEEDED=0
unit_exists() { systemctl cat "$1.service" >/dev/null 2>&1; }
enabled() { systemctl is-enabled --quiet "$1.service" 2>/dev/null; }

if unit_exists NetworkManager; then
    if enabled NetworkManager; then
        info "NetworkManager already enabled"
    else
        OTHERS=()
        for s in iwd systemd-networkd dhcpcd connman netctl wicd; do
            enabled "$s" && OTHERS+=("$s")
        done
        if [ "${#OTHERS[@]}" -gt 0 ]; then
            sudo systemctl disable "${OTHERS[@]/%/.service}"
            sudo systemctl enable NetworkManager.service
            info "NetworkManager enabled, ${OTHERS[*]} disabled (they would fight over the network)"
            REBOOT_NEEDED=1
        else
            sudo systemctl enable --now NetworkManager.service
            info "NetworkManager enabled and started"
        fi
    fi
else
    warn "NetworkManager is not installed: the Wi-Fi page of the control center needs it"
fi

HAS_BT=0
ls "$SYS"/class/bluetooth/hci* >/dev/null 2>&1 && HAS_BT=1
for i in "$SYS"/bus/usb/devices/*:*; do
    [ "$(cat "$i/bInterfaceClass" 2>/dev/null)$(cat "$i/bInterfaceSubClass" 2>/dev/null)$(cat "$i/bInterfaceProtocol" 2>/dev/null)" = e00101 ] && HAS_BT=1
done
if [ "$HAS_BT" = 0 ]; then
    info "no Bluetooth adapter found: bluetooth service left as it is"
elif ! unit_exists bluetooth; then
    warn "bluez is not installed: Bluetooth will not work"
elif enabled bluetooth; then
    info "bluetooth already enabled"
else
    sudo systemctl enable --now bluetooth.service
    info "bluetooth enabled and started"
fi

for r in "$SYS"/class/rfkill/rfkill*; do
    [ -r "$r/type" ] || continue
    t=$(cat "$r/type")
    case "$t" in wlan|bluetooth) ;; *) continue ;; esac
    if [ "$(cat "$r/hard" 2>/dev/null)" = 1 ]; then
        warn "$t is blocked by a hardware switch or the airplane-mode key: turn it on"
    elif [ "$(cat "$r/soft" 2>/dev/null)" = 1 ]; then
        sudo rfkill unblock "$t"
        info "$t was blocked (rfkill): unblocked"
    fi
done

HAS_WIFI_CARD=0
for d in "$SYS"/bus/pci/devices/*; do
    case "$(cat "$d/class" 2>/dev/null)" in 0x0280*) HAS_WIFI_CARD=1 ;; esac
done
if ls "$SYS"/class/ieee80211/phy* >/dev/null 2>&1; then
    info "Wi-Fi adapter ready"
elif [ "$HAS_WIFI_CARD" = 1 ]; then
    warn "a Wi-Fi card is present but has no driver loaded yet"
    REBOOT_NEEDED=1
else
    info "no Wi-Fi adapter found"
fi
if [ "$REBOOT_NEEDED" = 1 ]; then
    warn "reboot to load the new drivers and services; if Wi-Fi is still missing, the card needs a driver not in the kernel"
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
EDITORS=$(sh "$SRC/scripts/vscode.sh" --list | tr '\n' ' ' | sed 's/ *$//')
if [ -z "$EDITORS" ]; then
    info "no editor found (VS Code, VSCodium, Code - OSS, Cursor, Windsurf...): skipped"
    info "the extension can be installed by hand, see README"
elif [ "$(ask_yn "Install the Quickshell theme extension so the editor follows the shell theme ($EDITORS)?" false)" = true ]; then
    sh "$SRC/scripts/vscode.sh" || warn "VS Code themes: something went wrong (see above)"
else
    info "skipped (run scripts/vscode.sh later to add it)"
fi

say "Done."
