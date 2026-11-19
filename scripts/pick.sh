#!/bin/sh
set -u

mode=${1:-image}
title=${2:-Choose}
start=${3:-$HOME}
[ -d "$start" ] || start=$HOME

if command -v zenity >/dev/null 2>&1; then
    filter="Images | *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG *.webp *.WEBP"
    case "$mode" in
    dir) exec zenity --file-selection --directory --title="$title" --filename="$start/" 2>/dev/null ;;
    images) exec zenity --file-selection --multiple --separator="
" --title="$title" --filename="$start/" --file-filter="$filter" 2>/dev/null ;;
    *) exec zenity --file-selection --title="$title" --filename="$start/" --file-filter="$filter" 2>/dev/null ;;
    esac
fi

if command -v kdialog >/dev/null 2>&1; then
    types="image/png image/jpeg image/webp"
    case "$mode" in
    dir) exec kdialog --title "$title" --getexistingdirectory "$start" 2>/dev/null ;;
    images) exec kdialog --title "$title" --multiple --separate-output --getopenfilename "$start" "$types" 2>/dev/null ;;
    *) exec kdialog --title "$title" --getopenfilename "$start" "$types" 2>/dev/null ;;
    esac
fi

exit 3
