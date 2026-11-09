#!/bin/sh
# Installa il login di Quickshell per greetd (Arch e Fedora).
#
#   sudo ./install.sh [wallpaper]
#
# - copia la schermata in /etc/greetd/quickshell (il greeter gira come utente
#   "greeter" e non può leggere la tua home)
# - scrive /etc/greetd/config.toml (il vecchio resta come config.toml.bak)
# - rende la cartella tua: da lì in poi la shell la tiene aggiornata da sola
#   (greeter/sync.sh) con gli stessi file del blocco schermo
# - con "loginScreen": false in theme.json imposta il login automatico
# - NON abilita greetd: lo fai tu quando sei pronto (vedi README)
#
# Per provarla senza root: DEST=/tmp/prova ./install.sh  (non tocca /etc)
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
DEST=${DEST:-/etc/greetd/quickshell}
USER_NAME=${SUDO_USER:-$(id -un)}
WALLPAPER=${1:-}

# Wallpaper: argomento, oppure quello mostrato da awww/swww
if [ -z "$WALLPAPER" ]; then
    for q in awww swww; do
        if command -v "$q" >/dev/null 2>&1; then
            if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
                # Da root: il demone gira nella sessione dell'utente
                RUN="sudo -u $SUDO_USER env XDG_RUNTIME_DIR=/run/user/$(id -u "$SUDO_USER") WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}"
            else
                RUN=""
            fi
            WALLPAPER=$($RUN "$q" query 2>/dev/null | sed -n 's/.*image: //p' | head -n 1) || true
            [ -n "$WALLPAPER" ] && break
        fi
    done
fi
# Senza awww/swww (swaybg): l'ultimo sfondo salvato da scripts/wallpaper.sh
if [ -z "$WALLPAPER" ]; then
    USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
    WALLPAPER=$(cat "$USER_HOME/.local/state/quickshell-wallpaper" 2>/dev/null) || true
fi

mkdir -p "$DEST"

# Avvio della sessione: pulisce la console e nasconde il cursore prima di
# Hyprland (niente testo che lampeggia tra login e desktop). greetd unisce
# gli argomenti in una riga di shell, quindi si passa un solo file
if command -v start-hyprland >/dev/null 2>&1; then SESSION=start-hyprland; else SESSION=Hyprland; fi
printf '#!/bin/sh\nprintf "\\033[2J\\033[H\\033[?25l"\nexec %s >/dev/null 2>&1\n' "$SESSION" > "$DEST/session.sh"
chmod 755 "$DEST/session.sh"

printf '{\n  "user": "%s",\n  "session": ["%s/session.sh"]\n}\n' "$USER_NAME" "$DEST" > "$DEST/greeter.json"

# Schermata, tema, foto e sfondo (lo stesso script che poi usa la shell)
sh "$SRC/greeter/sync.sh" "$DEST" "$WALLPAPER"

# La cartella diventa dell'utente: la shell la aggiorna da sola, senza sudo
# (greeter.json e session.sh restano di root)
if [ "$(id -u)" -eq 0 ]; then
    chown -R "$USER_NAME" "$DEST"
    chown root "$DEST/greeter.json" "$DEST/session.sh"
fi

chmod -R a+rX "$DEST"

# Configurazione di greetd (solo se installiamo davvero in /etc)
if [ "$DEST" = "/etc/greetd/quickshell" ]; then
    if [ -f /etc/greetd/config.toml ] && [ ! -f /etc/greetd/config.toml.bak ]; then
        cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
    fi
    # Utente del greeter: "greeter" (Arch), "greetd" (Fedora). La sua home è "/", non
    # scrivibile: cache e stato di Quickshell/Qt vanno in /tmp
    GREETER_USER=greeter
    id "$GREETER_USER" >/dev/null 2>&1 || GREETER_USER=greetd
    cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "env XDG_CACHE_HOME=/tmp/greeter-cache XDG_STATE_HOME=/tmp/greeter-state cage -s -d -- quickshell -p $DEST"
user = "$GREETER_USER"
EOF
    # "loginScreen": false in theme.json -> login automatico: al primo avvio
    # greetd apre subito Hyprland, senza schermata di login. Uscendo dalla
    # sessione torna la schermata normale
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
