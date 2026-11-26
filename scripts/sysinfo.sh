#!/bin/sh

put() { [ -n "$2" ] && printf '%s\t%s\n' "$1" "$2"; }
has() { command -v "$1" >/dev/null 2>&1; }
clean() { tr -s ' ' | sed 's/^ //; s/ $//'; }

shelldir=${1:-}
mode=${2:-all}

if [ -r /etc/os-release ]; then
    . /etc/os-release
    put os "${PRETTY_NAME:-$NAME}"
    put osid "${ID:-linux}"
    put logo "${LOGO:-}"
    id=${ID:-linux}
    lg=${LOGO:-$id-logo}
    {
        if [ -n "$shelldir" ]; then
            printf '%s\n' "$shelldir/assets/logos/$id.svg" "$shelldir/assets/logos/$id.png"
        fi
        printf '%s\n' "/usr/share/pixmaps/$lg.svg" "/usr/share/pixmaps/$lg.png"
        find /usr/share/icons /usr/share/pixmaps -maxdepth 4 \( -name "$lg.svg" -o -name "$lg-icon.svg" \
            -o -name "$lg-symbolic.svg" -o -name "$id-logo.svg" -o -name "$id-logo-icon.svg" \
            -o -name "distributor-logo-$id.svg" -o -name "$lg.png" -o -name "$lg-icon.png" \
            -o -name "$id-logo.png" -o -name "distributor-logo-$id.png" \) 2>/dev/null \
            | awk '{ s = $0 ~ /\.svg$/ ? 0 : 1; m = match($0, /\/[0-9]+x[0-9]+\//); n = m ? substr($0, RSTART + 1) + 0 : 0; printf "%d %06d %s\n", s, 999999 - n, $0 }' \
            | sort | cut -d' ' -f3-
    } | awk '!seen[$0]++' | while IFS= read -r f; do
        [ -f "$f" ] && put logofile "$f"
    done
fi
[ "$mode" = logo ] && exit 0

put user "$(id -un)"
put hostname "$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)"
put fullname "$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f5 | cut -d, -f1)"

d=/sys/devices/virtual/dmi/id
host=""
for f in product_name board_name; do
    v=$(cat "$d/$f" 2>/dev/null | clean)
    case "$v" in ""|*"To be filled"*|*"To Be Filled"*|*"Default string"*|*"System Product Name"*|*"Not Applicable"*) continue ;; esac
    host=$v
    break
done
v=$(cat "$d/product_version" 2>/dev/null | clean)
case "$v" in ""|*[Ff]illed*|*Default*|*"Not Applicable"*|*None*|1.0|0.1) ;; *) host="$host $v" ;; esac
put host "$host"

put kernel "$(uname -r)"

pk=""
if has pacman; then pk="$(pacman -Qq 2>/dev/null | wc -l) (pacman)"
elif has rpm; then pk="$(rpm -qa 2>/dev/null | wc -l) (rpm)"
elif has dpkg-query; then pk="$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l) (dpkg)"
fi
if has flatpak; then
    n=$(flatpak list --app 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] && pk="${pk:+$pk, }$n (flatpak)"
fi
put packages "$pk"

sh_name=$(basename "${SHELL:-sh}")
sh_ver=$("${SHELL:-sh}" --version </dev/null 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)
put shell "$sh_name${sh_ver:+ $sh_ver}"

has hyprctl && put wm "Hyprland $(hyprctl version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
has quickshell && put quickshell "$(quickshell --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"

cpu=$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/(R)//g; s/(TM)//g; s/ CPU//; s/ @.*//; s/ [0-9]*-Core Processor//; s/ Processor//' | clean)
[ -n "$cpu" ] || cpu=$(grep -m 1 -E '^(Hardware|Model)' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | clean)
threads=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
mhz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
ghz=""
[ -n "$mhz" ] && ghz=$(awk -v k="$mhz" 'BEGIN { printf "%.2f GHz", k / 1000000 }')
put cpu "$cpu${threads:+ ($threads)}${ghz:+ @ $ghz}"

if has lspci; then
    lspci -mm 2>/dev/null | grep -E '"(VGA compatible controller|3D controller|Display controller)"' | while IFS= read -r line; do
        vendor=$(printf '%s\n' "$line" | awk -F'"' '{ print $4 }')
        dev=$(printf '%s\n' "$line" | awk -F'"' '{ print $6 }')
        case "$vendor" in
        *NVIDIA*) vendor=NVIDIA ;;
        *AMD*|*ATI*|*"Advanced Micro"*) vendor=AMD ;;
        *Intel*) vendor=Intel ;;
        esac
        name=$(printf '%s\n' "$dev" | sed -n 's/.*\[\(.*\)\].*/\1/p')
        [ -n "$name" ] || name=$dev
        case "$name" in "$vendor"*) put gpu "$name" ;; *) put gpu "$vendor $name" ;; esac
    done
elif has nvidia-smi; then
    nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | while IFS= read -r g; do put gpu "$g"; done
fi

term=${TERMINAL:-}
if [ -z "$term" ]; then
    for t in kitty foot alacritty wezterm ghostty ptyxis gnome-terminal kgx konsole xfce4-terminal xterm; do
        has "$t" && { term=$t; break; }
    done
fi
put terminal "$term"

if has gsettings; then
    put icons "$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
    c=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
    s=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)
    put cursor "$c${s:+ ($s px)}"
fi

put locale "${LC_ALL:-${LANG:-}}"

if has ip; then
    ip -4 -o addr show scope global 2>/dev/null | awk '{ print $2 ": " $4 }' | while IFS= read -r a; do put ip "$a"; done
fi
exit 0
