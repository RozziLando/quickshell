#!/bin/sh
# Sfondo del desktop con il programma che c'è:
#   - awww (o swww): animazioni di passaggio, ricorda da solo l'ultimo sfondo
#   - swaybg: nei repo ufficiali di Arch e Fedora (awww/swww su Fedora no),
#     senza animazioni; l'ultimo sfondo lo ricorda questo script
#
#   wallpaper.sh get                 percorso dello sfondo attuale
#   wallpaper.sh set FILE [opzioni]  cambia sfondo (opzioni: transizione awww)
#   wallpaper.sh restore             avvio della shell: accende il demone di
#                                    awww/swww se serve, o rimette swaybg
set -u

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-wallpaper"
has() { command -v "$1" >/dev/null 2>&1; }

# awww/swww funzionano solo col loro demone acceso: se nessuno l'ha avviato
# (es. un'installazione nuova senza la riga nell'autostart di Hyprland) lo
# avvia lo script. All'avvio di Hyprland può partire insieme alla shell:
# prima si aspetta un attimo, così non se ne avviano due
daemon() {
    "$1" query >/dev/null 2>&1 && return 0
    for _ in 1 2 3 4 5; do sleep 0.2; "$1" query >/dev/null 2>&1 && return 0; done
    setsid -f "$1-daemon" >/dev/null 2>&1
    for _ in $(seq 1 25); do sleep 0.2; "$1" query >/dev/null 2>&1 && return 0; done
    return 1
}

cmd=${1:-get}
[ $# -gt 0 ] && shift

case "$cmd" in
get)
    p=$( (awww query 2>/dev/null || swww query 2>/dev/null) | sed -n 's/.*image: //p' | head -n 1)
    [ -n "$p" ] || p=$(cat "$STATE" 2>/dev/null)
    printf '%s\n' "$p"
    ;;
set)
    f=${1:-}
    [ -f "$f" ] || exit 1
    shift
    mkdir -p "$(dirname "$STATE")" && printf '%s\n' "$f" > "$STATE"
    if has awww; then
        daemon awww
        exec awww img "$f" "$@"
    elif has swww; then
        daemon swww
        exec swww img "$f" "$@"
    elif has swaybg; then
        old=$(pgrep -x -u "$(id -u)" swaybg)
        setsid -f swaybg -m fill -i "$f" >/dev/null 2>&1
        # Il nuovo si disegna prima che si chiuda il vecchio: niente lampo nero
        if [ -n "$old" ]; then sleep 0.5; kill $old 2>/dev/null; fi
    fi
    ;;
restore)
    # awww/swww: il demone, appena acceso, rimette da solo l'ultimo sfondo
    if has awww; then daemon awww; exit 0; fi
    if has swww; then daemon swww; exit 0; fi
    # swaybg già avviato (es. dall'autostart di Hyprland): niente
    has swaybg || exit 0
    pgrep -x -u "$(id -u)" swaybg >/dev/null && exit 0
    f=$(cat "$STATE" 2>/dev/null)
    [ -f "$f" ] && setsid -f swaybg -m fill -i "$f" >/dev/null 2>&1
    ;;
esac
exit 0
