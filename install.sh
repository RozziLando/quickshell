#!/usr/bin/env bash
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd -P)

YES=0
PACKAGES_STEP=1
FORM=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --no-packages) PACKAGES_STEP=0 ;;
        --laptop) FORM=laptop ;;
        --desktop) FORM=desktop ;;
        -h|--help)
            printf '%s\n' \
                "Quickshell: dependencies (Arch, Debian, Ubuntu, Fedora, RHEL and their derivatives)." \
                "" \
                "  1. detects the distribution and installs only the missing dependencies (scripts/deps.sh)" \
                "  2. makes Wi-Fi and Bluetooth work: firmware, drivers, NetworkManager and bluetooth services" \
                "  3. turns on FastConnectable in /etc/bluetooth/main.conf" \
                "  4. leaves theme.json to the shell: at the first start it uses the desktop or laptop defaults" \
                "  5. creates the wallpaper folder (wallpaperDir in theme.json) if it is missing" \
                "  6. asks whether to set up the Quickshell login screen (greetd); if not, nothing is installed for it" \
                "  7. asks whether VS Code and its forks should follow the shell theme (scripts/vscode.sh)" \
                "" \
                "  ./install.sh -y             accept the defaults, ask nothing" \
                "  ./install.sh --no-packages  skip the package installation" \
                "  ./install.sh --laptop       install the laptop packages (brightnessctl, power profiles)" \
                "  ./install.sh --desktop      install the desktop packages (ddcutil, monitor brightness)" \
                "" \
                "Without --laptop / --desktop the script detects the computer (battery, built-in screen)."
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

DEPS="$SRC/scripts/deps.sh"
DISTRO=$(sh "$DEPS" family)
REASON=$(sh "$DEPS" reason)
if [ -n "$REASON" ] && [ "$PACKAGES_STEP" = 1 ]; then
    echo "$REASON"
    echo "Use ./install.sh --no-packages if you installed Quickshell and Hyprland by hand."
    exit 1
fi

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

[ -n "$FORM" ] || FORM=$(sh "$DEPS" form)

if [ "$PACKAGES_STEP" = 1 ]; then
    if [ "$FORM" = laptop ]; then
        say "Laptop detected: brightnessctl and upower for screen brightness and battery"
    else
        say "Desktop detected: ddcutil for the brightness of the monitors (displayOnDesktop in theme.json)"
    fi
    DEPS_ARGS=("--$FORM")
    [ "$YES" = 1 ] && DEPS_ARGS+=(-y)
    sh "$DEPS" install "${DEPS_ARGS[@]}" || warn "some packages are missing (see above)"
    if broadcom_wl_needed; then
        case "$DISTRO" in
            arch)
                say "Broadcom Wi-Fi without an open driver: installing broadcom-wl-dkms"
                HEADERS=()
                for k in linux linux-lts linux-zen linux-hardened linux-rt; do
                    pacman -Q "$k" >/dev/null 2>&1 && HEADERS+=("$k-headers")
                done
                if [ "$YES" = 1 ]; then BW=(--needed --noconfirm); else BW=(--needed); fi
                sudo pacman -S "${BW[@]}" broadcom-wl-dkms "${HEADERS[@]}" || warn "broadcom-wl-dkms could not be installed"
                ;;
            ubuntu)
                warn "Broadcom Wi-Fi without an open driver: install bcmwl-kernel-source (restricted) to use it" ;;
            debian)
                warn "Broadcom Wi-Fi without an open driver: install broadcom-sta-dkms (non-free) to use it" ;;
            *)
                warn "Broadcom Wi-Fi without an open driver: install akmod-wl from RPM Fusion (nonfree) to use it" ;;
        esac
    fi
    if [ "$FORM" = desktop ] && ! ls "$SYS"/class/i2c-dev/i2c-* >/dev/null 2>&1; then
        if ! grep -qsE '^[[:space:]]*i2c[-_]dev[[:space:]]*$' /etc/modules-load.d/*.conf /usr/lib/modules-load.d/*.conf; then
            echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
        fi
        sudo modprobe i2c-dev || warn "could not load i2c-dev: monitor brightness works after a reboot"
    fi
else
    say "Skipping packages (--no-packages)"
fi

say "Wi-Fi and Bluetooth"
REBOOT_NEEDED=0
unit_exists() { systemctl cat "$1.service" >/dev/null 2>&1; }
enabled() { systemctl is-enabled --quiet "$1.service" 2>/dev/null; }
active() { systemctl is-active --quiet "$1.service" 2>/dev/null; }
KVER=${KVER:-$(uname -r)}
MODDIR=${MODDIR:-/usr/lib/modules}
MODULES_OK=1
if [ ! -d "$MODDIR/$KVER" ]; then
    MODULES_OK=0
    warn "the kernel was updated during the installation: new drivers load only after a reboot"
    REBOOT_NEEDED=1
fi

WIFI_CARDS=()
for d in "$SYS"/bus/pci/devices/*; do
    case "$(cat "$d/class" 2>/dev/null)" in 0x0280*) WIFI_CARDS+=("$d") ;; esac
done
wifi_ready() { ls "$1"/ieee80211/* >/dev/null 2>&1; }
HAS_BT=0
ls "$SYS"/class/bluetooth/hci* >/dev/null 2>&1 && HAS_BT=1
USB_BT=0
for i in "$SYS"/bus/usb/devices/*:*; do
    [ "$(cat "$i/bInterfaceClass" 2>/dev/null)$(cat "$i/bInterfaceSubClass" 2>/dev/null)$(cat "$i/bInterfaceProtocol" 2>/dev/null)" = e00101 ] && USB_BT=1
done
[ "$USB_BT" = 1 ] && HAS_BT=1

if [ "$MODULES_OK" = 1 ]; then
    for d in "${WIFI_CARDS[@]}"; do
        wifi_ready "$d" && continue
        if broadcom_wl_needed && [ "$(cat "$d/vendor" 2>/dev/null)" = 0x14e4 ]; then
            for m in b43 b43legacy bcma ssb brcmsmac brcmfmac; do sudo modprobe -r "$m" 2>/dev/null || true; done
            MODS="wl"
        else
            MODS=$(modprobe -R "$(cat "$d/modalias" 2>/dev/null)" 2>/dev/null || true)
        fi
        for m in $MODS; do
            sudo modprobe -r "$m" 2>/dev/null || true
            sudo modprobe "$m" 2>/dev/null || warn "could not load the Wi-Fi driver $m"
        done
        [ -n "$MODS" ] && info "Wi-Fi driver loaded: $MODS"
    done
    if [ "$USB_BT" = 1 ] && ! ls "$SYS"/class/bluetooth/hci* >/dev/null 2>&1; then
        sudo modprobe -r btusb 2>/dev/null || true
        sudo modprobe btusb 2>/dev/null && info "Bluetooth driver loaded: btusb"
    fi
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        ready=1
        for d in "${WIFI_CARDS[@]}"; do wifi_ready "$d" || ready=0; done
        [ "$USB_BT" = 1 ] && ! ls "$SYS"/class/bluetooth/hci* >/dev/null 2>&1 && ready=0
        [ "$ready" = 1 ] && break
        sleep 0.5
    done
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

if unit_exists NetworkManager; then
    OTHERS=()
    NM_IWD=0
    grep -rqsE '^[[:space:]]*wifi\.backend[[:space:]]*=[[:space:]]*iwd' "${NMCONF:-/etc/NetworkManager}/" && NM_IWD=1
    for s in iwd systemd-networkd dhcpcd connman netctl wicd; do
        [ "$s" = iwd ] && [ "$NM_IWD" = 1 ] && continue
        enabled "$s" && OTHERS+=("$s")
    done
    if [ "${#OTHERS[@]}" -gt 0 ] && ! enabled NetworkManager; then
        sudo systemctl disable --now "${OTHERS[@]/%/.service}"
        info "${OTHERS[*]} stopped and disabled (they would fight with NetworkManager)"
        case " ${OTHERS[*]} " in *" iwd "*) warn "Wi-Fi networks saved by iwd are not imported: connect again from the Wi-Fi page" ;; esac
    fi
    if ! enabled NetworkManager; then
        sudo systemctl enable --now NetworkManager.service
        info "NetworkManager enabled and started"
    elif ! active NetworkManager; then
        sudo systemctl start NetworkManager.service
        info "NetworkManager started"
    else
        info "NetworkManager already running"
    fi
    if [ "${#WIFI_CARDS[@]}" -gt 0 ] && command -v nmcli >/dev/null 2>&1; then
        nmcli radio wifi on 2>/dev/null || true
    fi
else
    warn "NetworkManager is not installed: the Wi-Fi page of the control center needs it"
fi

if [ "$HAS_BT" = 0 ]; then
    info "no Bluetooth adapter found: bluetooth service left as it is"
elif ! unit_exists bluetooth; then
    warn "bluez is not installed: Bluetooth will not work"
elif ! enabled bluetooth; then
    sudo systemctl enable --now bluetooth.service
    info "bluetooth enabled and started"
elif ! active bluetooth; then
    sudo systemctl start bluetooth.service
    info "bluetooth started"
else
    info "bluetooth already running"
fi

if [ "${#WIFI_CARDS[@]}" -eq 0 ]; then
    if ls "$SYS"/class/ieee80211/phy* >/dev/null 2>&1; then info "Wi-Fi ready"; else info "no Wi-Fi adapter found"; fi
else
    for d in "${WIFI_CARDS[@]}"; do
        if wifi_ready "$d"; then
            info "Wi-Fi ready"
        else
            warn "the Wi-Fi card $(basename "$d") has no working driver yet"
            REBOOT_NEEDED=1
        fi
    done
fi
if [ "$USB_BT" = 1 ]; then
    if ls "$SYS"/class/bluetooth/hci* >/dev/null 2>&1; then info "Bluetooth ready"; else warn "the Bluetooth adapter has no working driver yet"; REBOOT_NEEDED=1; fi
fi
if [ "$REBOOT_NEEDED" = 1 ]; then
    warn "reboot once; if Wi-Fi or Bluetooth are still missing after that, the card needs a driver that is not in the kernel"
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

say "Settings"
if [ -s "$SRC/theme.json" ]; then
    info "theme.json found: your settings are kept"
else
    info "theme.json is created at the first start, with the defaults for this $FORM"
fi

say "Wallpapers"
THEME_FILE="$SRC/theme.json"
[ -s "$THEME_FILE" ] || THEME_FILE="$SRC/theme.default.json"
WALL_DIR=$(sed -n 's/.*"wallpaperDir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$THEME_FILE" 2>/dev/null | head -n 1)
WALL_DIR=${WALL_DIR:-~/Wallpapers}
WALL_DIR=${WALL_DIR/#\~/$HOME}
if [ ! -d "$WALL_DIR" ]; then
    mkdir -p "$WALL_DIR"
    info "created $WALL_DIR: put your wallpapers there (png, jpg, webp)"
else
    WALL_COUNT=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | wc -l)
    if [ "$WALL_COUNT" -eq 0 ]; then
        info "$WALL_DIR has no images yet: put your wallpapers there (png, jpg, webp)"
    else
        info "$WALL_COUNT wallpapers in $WALL_DIR"
    fi
fi
info "at the first start the shell applies one of them; then pick them in the launcher (Tab)"

OTHER_NOTIFY=""
for n in mako dunst swaync xfce4-notifyd; do command -v "$n" >/dev/null 2>&1 && OTHER_NOTIFY="$OTHER_NOTIFY $n"; done
if [ -n "$OTHER_NOTIFY" ]; then
    say "Notifications"
    warn "also installed:$OTHER_NOTIFY. It can take the notifications before the shell starts:"
    warn "remove it, or make sure it is not started by your Hyprland config"
fi

say "Login screen"
if grep -qs quickshell /etc/greetd/config.toml; then
    info "the Quickshell login screen is already set up"
    if [ "$(ask_yn "Refresh it with the current settings?" false)" = true ]; then
        sh "$SRC/greeter/install.sh" $( [ "$YES" = 1 ] && echo -y ) || warn "login screen: something went wrong (see above)"
    fi
elif [ "$(ask_yn "Use the Quickshell login screen (installs greetd and cage, replaces the current login manager)?" false)" = true ]; then
    sh "$SRC/greeter/install.sh" $( [ "$YES" = 1 ] && echo -y ) || warn "login screen: something went wrong (see above)"
else
    info "skipped: nothing installed, the current login manager stays (run greeter/install.sh later to add it)"
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
