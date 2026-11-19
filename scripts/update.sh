#!/bin/sh
set -u

dir=${1:?}
repo=${2:?}
branch=${3:?}
status=${4:?}
url=${5:-https://github.com/$repo/archive/refs/heads/$branch.tar.gz}

say() { printf '%s\n' "$*" > "$status.tmp" && mv -f "$status.tmp" "$status"; }
fail() { say "error	$*"; exit 1; }

restart() {
    real=$(cd "$dir" 2>/dev/null && pwd -P)
    main=$(cd "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell" 2>/dev/null && pwd -P)
    [ -n "$real" ] && [ "$real" = "$main" ] || return 0
    pgrep -x quickshell >/dev/null 2>&1 || return 0
    pkill -x quickshell
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x quickshell >/dev/null 2>&1 || break; sleep 0.3; done
    if ! { command -v hyprctl >/dev/null 2>&1 && { hyprctl eval 'hl.exec_cmd("quickshell")' 2>/dev/null | grep -qx ok \
            || hyprctl dispatch exec quickshell 2>/dev/null | grep -qx ok; }; }; then
        setsid -f quickshell >/dev/null 2>&1
    fi
    for _ in $(seq 1 30); do
        sleep 0.5
        quickshell ipc call settings open >/dev/null 2>&1 && break
    done
}

finish() {
    say "done	$1"
    restart
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a Quickshell "Quickshell updated" "Your settings, avatar, wallpapers and themes were kept." || true
    fi
    exit 0
}

[ -f "$dir/shell.qml" ] || fail "Not a Quickshell folder"
say "running	$$"

if [ -d "$dir/.git" ]; then
    command -v git >/dev/null 2>&1 || fail "git is not installed"
    out=$(git -C "$dir" pull --ff-only 2>&1) || fail "git pull failed: $(printf '%s' "$out" | tail -n 1)"
    finish "$(git -C "$dir" rev-parse HEAD)"
fi

command -v curl >/dev/null 2>&1 || fail "curl is not installed"
tmp=$(mktemp -d) || fail "Cannot create a temporary folder"
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' INT TERM HUP

curl -fsSL --retry 2 --connect-timeout 15 --max-time 300 "$url" -o "$tmp/src.tar.gz" \
    || fail "Download failed, check the connection"
mkdir "$tmp/new"
tar -xzf "$tmp/src.tar.gz" --strip-components=1 -C "$tmp/new" 2>/dev/null || fail "The download is damaged"
[ -f "$tmp/new/shell.qml" ] && [ -f "$tmp/new/VERSION" ] || fail "The download is incomplete"

(cd "$tmp/new" && find . -type f ! -path ./theme.json | sed 's|^\./||' | LC_ALL=C sort) > "$tmp/files"

if [ -f "$dir/.update-files" ]; then
    LC_ALL=C sort "$dir/.update-files" | LC_ALL=C comm -23 - "$tmp/files" | while IFS= read -r f; do
        case "$f" in ""|/*|*..*|theme.json|assets/avatar.*) continue ;; esac
        rm -f "$dir/$f"
        d=$(dirname "$f")
        while [ "$d" != "." ] && rmdir "$dir/$d" 2>/dev/null; do d=$(dirname "$d"); done
    done
fi

[ -f "$dir/theme.json" ] || cp "$tmp/new/theme.json" "$dir/theme.json"
(cd "$tmp/new" && tar -cf - --exclude=./theme.json .) | (cd "$dir" && tar -xf -) \
    || fail "Cannot copy the new files"
cp "$tmp/files" "$dir/.update-files"

finish "$(cut -d' ' -f1 "$dir/VERSION")"
