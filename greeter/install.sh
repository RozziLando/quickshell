#!/bin/sh
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
DEST=${DEST:-/etc/greetd/quickshell}
USER_NAME=${SUDO_USER:-$(id -un)}
WALLPAPER=${1:-}

if [ -z "$WALLPAPER" ]; then
    for q in awww swww; do
        if command -v "$q" >/dev/null 2>&1; then
            if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
                RUN="sudo -u $SUDO_USER env XDG_RUNTIME_DIR=/run/user/$(id -u "$SUDO_USER") WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}"
            else
                RUN=""
            fi
            WALLPAPER=$($RUN "$q" query 2>/dev/null | sed -n 's/.*image: //p' | head -n 1) || true
            [ -n "$WALLPAPER" ] && break
        fi
    done
fi
if [ -z "$WALLPAPER" ]; then
    USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
    WALLPAPER=$(cat "$USER_HOME/.local/state/quickshell-wallpaper" 2>/dev/null) || true
fi

mkdir -p "$DEST"

if command -v start-hyprland >/dev/null 2>&1; then SESSION=start-hyprland; else SESSION=Hyprland; fi
printf '#!/bin/sh\nprintf "\\033[2J\\033[H\\033[?25l"\nexec %s >/dev/null 2>&1\n' "$SESSION" > "$DEST/session.sh"
chmod 755 "$DEST/session.sh"

printf '{\n  "user": "%s",\n  "session": ["%s/session.sh"]\n}\n' "$USER_NAME" "$DEST" > "$DEST/greeter.json"

sh "$SRC/greeter/sync.sh" "$DEST" "$WALLPAPER"

if [ "$(id -u)" -eq 0 ]; then
    chown -R "$USER_NAME" "$DEST"
    chown root "$DEST/greeter.json" "$DEST/session.sh"
fi

chmod -R a+rX "$DEST"

if [ "$DEST" = "/etc/greetd/quickshell" ]; then
    if [ -f /etc/greetd/config.toml ] && [ ! -f /etc/greetd/config.toml.bak ]; then
        cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
    fi
    GREETER_USER=greeter
    id "$GREETER_USER" >/dev/null 2>&1 || GREETER_USER=greetd
    cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "env XDG_CACHE_HOME=/tmp/greeter-cache XDG_STATE_HOME=/tmp/greeter-state cage -s -d -- quickshell -p $DEST"
user = "$GREETER_USER"
EOF
    if grep -Eq '"loginScreen"[[:space:]]*:[[:space:]]*false' "$SRC/theme.json"; then
        cat >> /etc/greetd/config.toml <<EOF

[initial_session]
command = "$DEST/session.sh"
user = "$USER_NAME"
EOF
        echo "Automatic login enabled for $USER_NAME (loginScreen: false)"
    fi
    echo "Installed in $DEST and wrote /etc/greetd/config.toml"
else
    echo "Preview in $DEST:  qs -p $DEST"
fi
