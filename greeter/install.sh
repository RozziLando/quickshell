#!/bin/sh
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
DEFAULT_DEST=/etc/greetd/quickshell
DEST=${DEST:-$DEFAULT_DEST}
SESSION_BIN=/usr/local/bin/quickshell-hyprland-session
DRY=0
YES=0
USER_NAME=""
WALLPAPER=""

usage() {
    printf '%s\n' \
        "Quickshell login screen (greetd + cage), Arch and Fedora." \
        "" \
        "  sudo greeter/install.sh [options] [wallpaper]" \
        "" \
        "Installs greetd and cage, copies the login screen to $DEFAULT_DEST," \
        "writes /etc/greetd/config.toml, disables the current display manager" \
        "(sddm, gdm, lightdm, ly...) and enables greetd: the login screen is" \
        "used from the next boot." \
        "" \
        "  --user NAME   user shown on the login screen (default: the one running sudo)" \
        "  --dry-run     print what would be done, change nothing" \
        "  -y, --yes     do not ask for confirmation" \
        "  -h, --help    this help" \
        "" \
        "Preview without root: DEST=/tmp/preview greeter/install.sh, then qs -p /tmp/preview"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --user) USER_NAME=${2:-}; shift ;;
        --user=*) USER_NAME=${1#--user=} ;;
        --dry-run) DRY=1 ;;
        -y|--yes) YES=1 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1 (see --help)"; exit 1 ;;
        *) WALLPAPER=$1 ;;
    esac
    shift
done

PREVIEW=0
[ "$DEST" != "$DEFAULT_DEST" ] && PREVIEW=1

if [ "$PREVIEW" = 0 ] && [ "$DRY" = 0 ] && [ "$(id -u)" -ne 0 ]; then
    set --
    [ -n "$USER_NAME" ] && set -- "$@" --user "$USER_NAME"
    [ "$YES" = 1 ] && set -- "$@" -y
    [ -n "$WALLPAPER" ] && set -- "$@" "$WALLPAPER"
    exec sudo sh "$0" "$@"
fi

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*"; }
run() {
    if [ "$DRY" = 1 ]; then printf '    + %s\n' "$*"; else "$@"; fi
}
write() {
    if [ "$DRY" = 1 ]; then
        printf '    + write %s:\n' "$1"
        sed 's/^/        | /'
    else
        cat > "$1"
    fi
}

[ -n "$USER_NAME" ] || USER_NAME=${SUDO_USER:-}
[ -n "$USER_NAME" ] || [ "$(id -u)" -eq 0 ] || USER_NAME=$(id -un)
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = root ]; then
    echo "Which user should log in? Run it with sudo from your user, or pass --user NAME."
    exit 1
fi
if ! getent passwd "$USER_NAME" >/dev/null 2>&1; then
    echo "User $USER_NAME does not exist."
    exit 1
fi
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
USER_UID=$(id -u "$USER_NAME")

DISTRO=""
if [ -r /etc/os-release ]; then
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
        *" arch "*) DISTRO=arch ;;
        *" fedora "*) DISTRO=fedora ;;
    esac
fi

if [ -z "$WALLPAPER" ]; then
    for q in awww swww; do
        command -v "$q" >/dev/null 2>&1 || continue
        if [ "$(id -u)" -eq 0 ] && [ "$USER_NAME" != root ]; then
            WALLPAPER=$(sudo -u "$USER_NAME" env XDG_RUNTIME_DIR="/run/user/$USER_UID" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" "$q" query 2>/dev/null | sed -n 's/.*image: //p' | head -n 1) || true
        else
            WALLPAPER=$("$q" query 2>/dev/null | sed -n 's/.*image: //p' | head -n 1) || true
        fi
        [ -n "$WALLPAPER" ] && break
    done
fi
[ -n "$WALLPAPER" ] || WALLPAPER=$(cat "$USER_HOME/.local/state/quickshell-wallpaper" 2>/dev/null) || true

if command -v start-hyprland >/dev/null 2>&1; then HYPR=start-hyprland; else HYPR=Hyprland; fi
AUTOLOGIN=0
grep -Eq '"loginScreen"[[:space:]]*:[[:space:]]*false' "$SRC/theme.json" 2>/dev/null && AUTOLOGIN=1

if [ "$PREVIEW" = 1 ]; then
    say "Preview in $DEST"
    mkdir -p "$DEST"
    printf '#!/bin/sh\nprintf "\\033[2J\\033[H\\033[?25l"\nexec %s >/dev/null 2>&1\n' "$HYPR" > "$DEST/session.sh"
    chmod 755 "$DEST/session.sh"
    printf '{\n  "user": "%s",\n  "session": ["%s/session.sh"]\n}\n' "$USER_NAME" "$DEST" > "$DEST/greeter.json"
    sh "$SRC/greeter/sync.sh" "$DEST" "$WALLPAPER"
    chmod -R a+rX "$DEST"
    info "qs -p $DEST"
    exit 0
fi

if [ -z "$DISTRO" ]; then
    echo "Unsupported distribution: only Arch Linux and Fedora (and their derivatives) are supported."
    exit 1
fi

KNOWN_DMS="sddm gdm gdm3 lightdm lxdm xdm ly ly@tty2 lemurs emptty entrance cosmic-greeter slim"
PREV_DM=""
link=$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)
[ -n "$link" ] && PREV_DM=$(basename "$link" .service)
OTHER_DMS=""
for dm in $KNOWN_DMS; do
    if systemctl is-enabled "$dm.service" >/dev/null 2>&1; then
        case " $OTHER_DMS " in *" $dm "*) ;; *) OTHER_DMS="$OTHER_DMS $dm" ;; esac
    fi
done
[ -n "$PREV_DM" ] && [ "$PREV_DM" != greetd ] && case " $OTHER_DMS " in *" $PREV_DM "*) ;; *) OTHER_DMS="$OTHER_DMS $PREV_DM" ;; esac
OTHER_DMS=$(printf '%s\n' $OTHER_DMS | { grep -vx greetd || true; } | tr '\n' ' ' | sed 's/ *$//')

say "Quickshell login screen"
info "distribution:   $DISTRO"
info "user:           $USER_NAME"
info "session:        $HYPR"
info "wallpaper:      ${WALLPAPER:-none found}"
info "login screen:   $( [ "$AUTOLOGIN" = 1 ] && echo 'automatic login ("loginScreen": false)' || echo 'password ("loginScreen": true)')"
info "disabled:       ${OTHER_DMS:-no other display manager}"
if [ "$YES" = 0 ] && [ "$DRY" = 0 ] && [ -t 0 ]; then
    printf '    Continue? [Y/n] '
    read -r answer
    case "$answer" in [nN]*) echo "    Nothing changed."; exit 0 ;; esac
fi

say "Packages"
if [ "$DISTRO" = arch ]; then
    run pacman -S --needed --noconfirm greetd cage
else
    run dnf install -y greetd cage
fi

say "Greeter user"
GREETER_USER=""
if [ -f /etc/greetd/config.toml ]; then
    GREETER_USER=$(sed -n '/^\[default_session\]/,/^\[/{s/^[[:space:]]*user[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p}' /etc/greetd/config.toml | head -n 1)
fi
if [ -z "$GREETER_USER" ] || ! id "$GREETER_USER" >/dev/null 2>&1; then
    GREETER_USER=""
    for u in greeter greetd _greetd; do
        if id "$u" >/dev/null 2>&1; then GREETER_USER=$u; break; fi
    done
fi
if [ -z "$GREETER_USER" ]; then
    if [ "$DRY" = 1 ]; then
        GREETER_USER=greeter
        info "greetd not installed yet: assuming user \"greeter\""
    else
        echo "    The greetd package did not create its user (greeter / greetd)."
        exit 1
    fi
fi
info "$GREETER_USER"

say "Login screen files"
run mkdir -p "$DEST"
write "$SESSION_BIN" <<EOF
#!/bin/sh
printf '\033[2J\033[H\033[?25l'
exec $HYPR >/dev/null 2>&1
EOF
run chmod 755 "$SESSION_BIN"
printf '{\n  "user": "%s",\n  "session": ["%s"]\n}\n' "$USER_NAME" "$SESSION_BIN" | write "$DEST/greeter.json"
run sh "$SRC/greeter/sync.sh" "$DEST" "$WALLPAPER"
run chown -R "$USER_NAME" "$DEST"
run chown root:root "$DEST/greeter.json"
run chmod 644 "$DEST/greeter.json"
run chmod -R a+rX "$DEST"
[ -n "$PREV_DM" ] && [ "$PREV_DM" != greetd ] && printf '%s\n' "$PREV_DM" | write "$DEST/previous-display-manager"
info "files in $DEST (kept up to date by the shell, see greeter/sync.sh)"

say "greetd configuration"
run mkdir -p /etc/greetd
if [ -f /etc/greetd/config.toml ] && ! grep -q "quickshell -p $DEST" /etc/greetd/config.toml; then
    run cp /etc/greetd/config.toml "/etc/greetd/config.toml.bak-$(date +%Y%m%d-%H%M%S)"
    info "old config.toml saved as config.toml.bak-<date>"
fi
{
    printf '[terminal]\nvt = 1\n\n'
    printf '[default_session]\n'
    printf 'command = "env XDG_CACHE_HOME=/tmp/greeter-cache XDG_STATE_HOME=/tmp/greeter-state cage -s -d -- quickshell -p %s"\n' "$DEST"
    printf 'user = "%s"\n' "$GREETER_USER"
    if [ "$AUTOLOGIN" = 1 ]; then
        printf '\n[initial_session]\ncommand = "%s"\nuser = "%s"\n' "$SESSION_BIN" "$USER_NAME"
    fi
} | write /etc/greetd/config.toml

if command -v restorecon >/dev/null 2>&1; then
    run restorecon -R /etc/greetd "$SESSION_BIN"
fi

say "Display manager"
for dm in $OTHER_DMS; do
    run systemctl disable "$dm.service" 2>/dev/null || warn "could not disable $dm"
    info "disabled $dm"
done
run systemctl enable --force greetd.service
run systemctl set-default graphical.target
info "greetd enabled, graphical boot"

if [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ] && grep -q -- '--autologin' /etc/systemd/system/getty@tty1.service.d/override.conf; then
    warn "tty1 has an automatic login (getty@tty1 override): greetd takes tty1, so it is no longer used."
    if [ "$AUTOLOGIN" = 1 ]; then
        info "automatic login is now done by greetd (\"loginScreen\": false)"
    else
        warn "To log in without a password use \"loginScreen\": false in theme.json and run this script again."
    fi
fi

say "Done: the login screen starts at the next boot."
if [ -n "$PREV_DM" ] && [ "$PREV_DM" != greetd ]; then
    info "To go back: sudo systemctl disable greetd && sudo systemctl enable $PREV_DM"
else
    info "To go back: sudo systemctl disable greetd"
fi
