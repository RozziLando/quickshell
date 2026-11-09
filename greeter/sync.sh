#!/bin/sh
# Aggiorna la copia del login (/etc/greetd/quickshell) con i file del blocco
# schermo: stessa schermata, tema, foto e sfondo attuale. Non serve root: la
# cartella appartiene all'utente (la prepara install.sh). La shell lo lancia
# da sola (services/GreeterSync.qml) a ogni modifica, prima di dormire e di
# spegnere.
#
#   greeter/sync.sh [cartella] [sfondo]
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:-/etc/greetd/quickshell}
WALLPAPER=${2:-}

# Login non installato (o cartella non nostra): niente da fare
[ -d "$DEST" ] && [ -w "$DEST" ] || exit 0

# Copia solo se il file è cambiato
put() {
    mkdir -p "$(dirname "$2")"
    cmp -s "$1" "$2" 2>/dev/null || cp "$1" "$2"
}

put "$SRC/greeter/shell.qml"    "$DEST/shell.qml"
put "$SRC/lock/LoginView.qml"   "$DEST/lock/LoginView.qml"
put "$SRC/services/Theme.qml"   "$DEST/services/Theme.qml"
put "$SRC/widgets/LineIcon.qml" "$DEST/widgets/LineIcon.qml"
put "$SRC/services/Icons.qml"   "$DEST/services/Icons.qml"
for f in "$SRC"/assets/fonts/*.ttf; do put "$f" "$DEST/assets/fonts/$(basename "$f")"; done
put "$SRC/theme.json"           "$DEST/theme.json"
for f in "$SRC"/themes/*.json; do put "$f" "$DEST/themes/$(basename "$f")"; done

# Foto dell'utente: assets/avatar.png (o .jpg/.jpeg)
found=""
for f in "$SRC/assets/avatar.png" "$SRC/assets/avatar.jpg" "$SRC/assets/avatar.jpeg"; do
    if [ -f "$f" ]; then put "$f" "$DEST/avatar"; found=1; break; fi
done
[ -n "$found" ] || rm -f "$DEST/avatar"

# Sfondo: quello mostrato ora (awww/swww/swaybg), così il login ha l'ultimo usato
if [ -z "$WALLPAPER" ]; then
    WALLPAPER=$(sh "$SRC/scripts/wallpaper.sh" get) || true
fi
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    put "$WALLPAPER" "$DEST/wallpaper"
fi

chmod -R a+rX "$DEST" 2>/dev/null || true
