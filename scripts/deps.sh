#!/bin/sh
set -u

SYS=${SYS:-/sys}
OS_RELEASE=${OS_RELEASE:-/etc/os-release}

cmd=${1:-check}
[ $# -gt 0 ] && shift
YES=0
FORM=""
UPDATE=0
NEW=""
for a in "$@"; do
    case "$a" in
        -y|--yes) YES=1 ;;
        --laptop) FORM=laptop ;;
        --desktop) FORM=desktop ;;
        --update) UPDATE=1 ;;
    esac
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*" >&2; }
info() { printf '    %s\n' "$*" >&2; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*" >&2; }
has()  { command -v "$1" >/dev/null 2>&1; }

ID=""; ID_LIKE=""; VERSION_ID=""; VERSION_CODENAME=""; UBUNTU_CODENAME=""; PRETTY_NAME=""
[ -r "$OS_RELEASE" ] && . "$OS_RELEASE"
IDS=" ${ID:-} ${ID_LIKE:-} "
CODENAME=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
MAJOR=${VERSION_ID%%.*}

FAMILY=""
KNOWN=1
case "$IDS" in
    *" arch "*|*" archarm "*) FAMILY=arch ;;
    *" suse "*|*" opensuse "*|*" amzn "*) KNOWN=0 ;;
esac
if [ -z "$FAMILY" ] && [ "$KNOWN" = 1 ]; then
    case "$IDS" in
        *" fedora "*|*" rhel "*|*" centos "*)
            if [ "${MAJOR:-0}" -ge 30 ] 2>/dev/null; then FAMILY=fedora; else FAMILY=el; fi ;;
        *" ubuntu "*) FAMILY=ubuntu ;;
        *" debian "*) FAMILY=debian ;;
    esac
fi
if [ -z "$FAMILY" ] && [ "$KNOWN" = 1 ]; then
    if has pacman; then FAMILY=arch
    elif has apt-get; then FAMILY=debian
    elif has dnf; then FAMILY=fedora
    fi
fi
[ "$ID" = fedora ] && FAMILY=fedora
OSTREE=0
[ -e /run/ostree-booted ] && OSTREE=1

detect_form() {
    for b in "$SYS"/class/power_supply/*; do
        [ "$(cat "$b/type" 2>/dev/null)" = Battery ] || continue
        [ "$(cat "$b/scope" 2>/dev/null)" = Device ] && continue
        echo laptop; return
    done
    if ls "$SYS"/class/backlight/* >/dev/null 2>&1; then echo laptop; return; fi
    case "$(cat "$SYS"/class/dmi/id/chassis_type 2>/dev/null)" in 8|9|10|11|14|30|31|32) echo laptop; return ;; esac
    echo desktop
}
[ -n "$FORM" ] || FORM=$(detect_form)

has_wifi() {
    ls "$SYS"/class/ieee80211/* >/dev/null 2>&1 && return 0
    for d in "$SYS"/bus/pci/devices/*; do
        case "$(cat "$d/class" 2>/dev/null)" in 0x0280*) return 0 ;; esac
    done
    return 1
}

unsupported_reason() {
    case "$FAMILY" in
        arch|fedora) ;;
        ubuntu)
            case "$CODENAME" in
                focal|jammy|noble|oracular|plucky) echo "${PRETTY_NAME:-Ubuntu $VERSION_ID} is too old: Ubuntu 25.10 or newer (or a derivative based on it) is needed" ;;
            esac ;;
        debian)
            case "$CODENAME" in
                buster|bullseye|bookworm) echo "${PRETTY_NAME:-Debian $VERSION_ID} is too old: Debian 13 or newer is needed" ;;
            esac ;;
        el)
            [ -n "$MAJOR" ] && [ "$MAJOR" -lt 10 ] 2>/dev/null && echo "${PRETTY_NAME:-This system} is too old: version 10 or newer is needed" ;;
        "") echo "Unsupported distribution: Arch, Debian, Ubuntu, Fedora, RHEL and their derivatives are supported" ;;
    esac
    [ "$OSTREE" = 1 ] && echo "${PRETTY_NAME:-This system} is an image-based system (rpm-ostree): install the packages with rpm-ostree or a toolbox"
}

core_list() {
    case "$FAMILY" in
        arch) echo "quickshell hyprland networkmanager bluez bluez-utils pipewire wireplumber libpulse
                    playerctl grim slurp wl-clipboard libnotify glib2 diffutils qt6-imageformats qt6-svg qt6-wayland
                    inter-font noto-fonts-emoji zenity curl pciutils xdg-user-dirs git upower" ;;
        ubuntu|debian) echo "quickshell hyprland network-manager bluez pipewire wireplumber pulseaudio-utils
                    playerctl grim slurp wl-clipboard libnotify-bin libglib2.0-bin diffutils qt6-wayland
                    fonts-inter fonts-noto-color-emoji zenity curl pciutils xdg-user-dirs git upower" ;;
        fedora) echo "quickshell hyprland NetworkManager NetworkManager-wifi bluez pipewire wireplumber
                    pulseaudio-utils playerctl grim slurp wl-clipboard libnotify glib2 diffutils qt6-qtimageformats
                    qt6-qtsvg qt6-qtwayland rsms-inter-fonts google-noto-color-emoji-fonts zenity curl pciutils
                    xdg-user-dirs git upower" ;;
        el) echo "quickshell hyprland NetworkManager NetworkManager-wifi bluez pipewire wireplumber
                    pulseaudio-utils glib2 diffutils qt6-qtimageformats qt6-qtsvg qt6-qtwayland curl pciutils
                    xdg-user-dirs git upower" ;;
    esac
    if [ "$FORM" = laptop ]; then echo brightnessctl; else echo ddcutil; fi
}

extra_list() {
    case "$FAMILY" in
        arch) echo "noto-fonts-cjk linux-firmware" ;;
        ubuntu|debian) echo "qml6-module-qtquick-effects qml6-module-qtquick-dialogs qml6-module-qtquick-controls
                    qml6-module-qtquick-layouts qml6-module-qtquick-templates qml6-module-qt-labs-folderlistmodel
                    qml6-module-qtquick-shapes qml6-module-qtquick-window qml6-module-qtqml-workerscript
                    qt6-image-formats-plugins qt6-svg-plugins fonts-noto-cjk" ;;
        fedora|el) echo "google-noto-sans-cjk-fonts linux-firmware iwlwifi-mvm-firmware iwlwifi-dvm-firmware
                    realtek-firmware atheros-firmware brcmfmac-firmware mt7xxx-firmware webp-pixbuf-loader
                    playerctl grim slurp wl-clipboard libnotify zenity rsms-inter-fonts google-noto-color-emoji-fonts" ;;
    esac
    [ "$FAMILY" = ubuntu ] && echo linux-firmware
    has_wifi && echo wireless-regdb
}

choice_list() {
    case "$FAMILY" in
        fedora|el) echo "pipewire-pulseaudio|pulseaudio" ;;
        *) echo "pipewire-pulse|pulseaudio" ;;
    esac
    case "$FAMILY" in
        arch|ubuntu|debian) echo "awww|swww|swaybg" ;;
        *) echo "swww|swaybg" ;;
    esac
    [ "$FORM" = laptop ] || return 0
    case "$FAMILY" in
        fedora|el) echo "tuned-ppd|power-profiles-daemon|tlp|auto-cpufreq" ;;
        *) echo "power-profiles-daemon|tuned-ppd|tlp|auto-cpufreq|tuned" ;;
    esac
}

installed() {
    case "$1" in
        quickshell) has quickshell && return 0 ;;
        hyprland) { has Hyprland || has hyprland; } && return 0 ;;
    esac
    case "$FAMILY" in
        arch) [ -z "$(pacman -T "$1" 2>/dev/null)" ] ;;
        ubuntu|debian) dpkg-query -W -f '${Status}' "$1" 2>/dev/null | grep -q 'install ok installed' ;;
        fedora|el) rpm -q --whatprovides "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

available() {
    case "$FAMILY" in
        arch) pacman -Si "$1" >/dev/null 2>&1 ;;
        ubuntu|debian)
            c=$(apt-cache policy "$1" 2>/dev/null | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p' | head -n 1)
            [ -n "$c" ] && [ "$c" != "(none)" ] ;;
        fedora|el) dnf -q -C list --available "$1" >/dev/null 2>&1 || dnf -q -C list --installed "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

missing() {
    for p in $(core_list); do
        installed "$p" || echo "$p"
    done
    for p in $(extra_list); do
        installed "$p" && continue
        available "$p" && echo "$p"
    done
    for alts in $(choice_list); do
        done_one=0
        for p in $(echo "$alts" | tr '|' ' '); do
            if installed "$p"; then done_one=1; break; fi
        done
        [ "$done_one" = 1 ] && continue
        for p in $(echo "$alts" | tr '|' ' '); do
            if available "$p"; then echo "$p"; break; fi
        done
    done
}

as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

pm_install() {
    case "$FAMILY" in
        arch)
            if [ "$YES" = 1 ]; then as_root pacman -S --needed --noconfirm "$@"
            else as_root pacman -S --needed "$@"; fi ;;
        ubuntu|debian)
            if [ "$YES" = 1 ]; then as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-remove "$@"
            else as_root apt-get install --no-remove "$@"; fi ;;
        fedora|el)
            if [ "$YES" = 1 ]; then as_root dnf install -y "$@"
            else as_root dnf install "$@"; fi ;;
    esac
}

install_each() {
    failed=""
    if pm_install "$@"; then return 0; fi
    if [ "$YES" = 0 ]; then
        printf '    Something was not installed. Try one package at a time? [y/N] ' >&2
        r=""
        read -r r </dev/tty 2>/dev/null || r=""
        case "$r" in [yY]*) ;; *) warn "not installed: $*"; return 1 ;; esac
    else
        warn "installing everything at once did not work: trying one package at a time"
    fi
    old=$YES
    YES=1
    for p in "$@"; do
        pm_install "$p" >/dev/null 2>&1 || failed="$failed $p"
    done
    YES=$old
    [ -z "$failed" ] && return 0
    warn "not installed:$failed"
    return 1
}

apt_has_line() {
    grep -rqsE "$1" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
}

prepare_debian() {
    say "Updating the package lists"
    as_root apt-get update || warn "apt-get update reported errors"
    BACKPORTS=""
    need_qs=0; need_hy=0
    installed quickshell || available quickshell || need_qs=1
    installed hyprland || available hyprland || need_hy=1
    [ "$need_qs" = 0 ] && [ "$need_hy" = 0 ] && return 0
    if [ "$FAMILY" = debian ] && [ "$ID" = debian ] && [ -n "$CODENAME" ] \
            && curl -fsI --max-time 15 "https://deb.debian.org/debian/dists/$CODENAME-backports/Release" >/dev/null 2>&1; then
        if ! apt_has_line "$CODENAME-backports"; then
            say "Enabling $CODENAME-backports (Quickshell and Hyprland come from there)"
            printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: %s-backports\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n' "$CODENAME" \
                | as_root tee /etc/apt/sources.list.d/quickshell-backports.sources >/dev/null
            as_root apt-get update || warn "apt-get update reported errors"
        fi
        BACKPORTS="$CODENAME-backports"
        return 0
    fi
    if [ "$FAMILY" = ubuntu ] && [ "$need_qs" = 1 ]; then
        say "Quickshell is not in the Ubuntu archive for this release: adding the Dank Linux PPA"
        has add-apt-repository || pm_install software-properties-common
        as_root add-apt-repository -y ppa:avengemedia/danklinux || warn "the PPA could not be added"
        as_root apt-get update || warn "apt-get update reported errors"
    fi
    if [ "$FAMILY" = ubuntu ] && [ "$need_hy" = 1 ] && ! available hyprland; then
        as_root add-apt-repository -y universe >/dev/null 2>&1 && as_root apt-get update >/dev/null 2>&1
    fi
}

copr_enable() {
    if ! dnf copr --help >/dev/null 2>&1; then
        as_root dnf install -y 'dnf-command(copr)' >/dev/null 2>&1 || as_root dnf install -y dnf-plugins-core
    fi
    as_root dnf copr enable -y "$@"
}

prepare_rpm() {
    if [ "$FAMILY" = el ]; then
        if ! rpm -q epel-release >/dev/null 2>&1; then
            say "Enabling EPEL"
            as_root dnf install -y epel-release 2>/dev/null \
                || as_root dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$MAJOR.noarch.rpm" \
                || warn "EPEL could not be enabled"
        fi
        if has crb; then as_root crb enable >/dev/null 2>&1
        else as_root dnf config-manager --set-enabled crb >/dev/null 2>&1 || true
        fi
    fi
    as_root dnf makecache >/dev/null 2>&1 || true
    if ! installed quickshell && ! available quickshell; then
        say "Quickshell comes from the errornointernet/quickshell COPR"
        copr_enable errornointernet/quickshell || warn "the Quickshell COPR could not be enabled"
    fi
    if ! installed hyprland && ! available hyprland; then
        if [ "$FAMILY" = el ]; then
            say "Hyprland comes from the perutzit/hyprland-el COPR"
            copr_enable perutzit/hyprland-el || warn "the Hyprland COPR could not be enabled"
        else
            say "Hyprland comes from the sdegler/hyprland COPR"
            copr_enable sdegler/hyprland || copr_enable solopasha/hyprland || warn "the Hyprland COPR could not be enabled"
        fi
    fi
    as_root dnf makecache >/dev/null 2>&1 || true
}

enable_services() {
    for s in power-profiles-daemon tuned tuned-ppd; do
        case " $NEW " in *" $s "*) ;; *) continue ;; esac
        installed "$s" || continue
        systemctl cat "$s.service" >/dev/null 2>&1 || continue
        systemctl is-enabled --quiet "$s.service" 2>/dev/null && continue
        as_root systemctl enable --now "$s.service" >/dev/null 2>&1 && info "$s enabled"
    done
}

do_install() {
    reason=$(unsupported_reason)
    if [ -n "$reason" ]; then
        printf '%s\n' "$reason" >&2
        return 2
    fi
    case "$FAMILY" in
        arch) say "${PRETTY_NAME:-Arch Linux}: pacman, only missing packages are installed" ;;
        ubuntu|debian) say "${PRETTY_NAME:-Debian}: apt, only missing packages, nothing is ever removed"; prepare_debian ;;
        fedora|el) say "${PRETTY_NAME:-Fedora}: dnf, only missing packages, nothing is ever removed"; prepare_rpm ;;
    esac
    list=$(missing | awk '!seen[$0]++' | tr '\n' ' ')
    status=0
    if [ "$FAMILY" = debian ] && [ -n "${BACKPORTS:-}" ]; then
        bp=""
        for p in quickshell hyprland; do
            case " $list " in *" $p "*) bp="$bp $p"; list=$(printf '%s' " $list " | sed "s/ $p / /") ;; esac
        done
        if [ -n "$bp" ]; then
            say "From $BACKPORTS:$bp"
            if [ "$YES" = 1 ]; then as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-remove -t "$BACKPORTS" $bp || status=1
            else as_root apt-get install --no-remove -t "$BACKPORTS" $bp || status=1; fi
        fi
    fi
    list=$(echo $list)
    NEW="$list"
    case " $NEW " in *" tuned-ppd "*) NEW="$NEW tuned" ;; esac
    if [ -z "$list" ]; then
        info "all the dependencies are installed"
    else
        say "Installing: $list"
        install_each $list || status=1
    fi
    enable_services
    for c in quickshell hyprland; do
        if ! installed "$c"; then
            warn "$c is still missing: install it by hand (see the README), the shell cannot start without it"
            status=1
        fi
    done
    return $status
}

case "$cmd" in
    family) echo "${FAMILY:-unknown}" ;;
    form) echo "$FORM" ;;
    reason) unsupported_reason ;;
    check)
        [ -n "$(unsupported_reason)" ] && exit 2
        out=$(missing | awk '!seen[$0]++')
        [ -z "$out" ] && exit 0
        printf '%s\n' "$out"
        exit 1 ;;
    install)
        do_install
        code=$?
        if [ "$UPDATE" = 1 ]; then
            printf '\n'
            [ "$code" = 0 ] && printf 'Done. ' || printf 'Some packages could not be installed (see above). '
            printf 'Press Enter to close this window.'
            read -r _ || true
        fi
        exit $code ;;
    *) echo "usage: deps.sh check|install [-y] [--laptop|--desktop]" >&2; exit 64 ;;
esac
