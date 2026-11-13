#!/bin/sh
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
EXT="$SRC/vscode/quickshell-theme-sync"
MODE=install
case "${1:-}" in
    --pack) MODE=pack ;;
    --list) MODE=list ;;
    "") ;;
    *) echo "usage: scripts/vscode.sh [--pack | --list]"; exit 1 ;;
esac

NATIVE="code code-insiders codium codium-insiders vscodium vscodium-insiders code-oss
cursor windsurf windsurf-next positron kiro trae void antigravity code-server"
FLATPAK="com.visualstudio.code com.visualstudio.code.insiders com.vscodium.codium
com.vscodium.codium-insiders com.visualstudio.code-oss"

run_editor() {
    e=$1; shift
    case "$e" in
        flatpak:*) flatpak run "${e#flatpak:}" "$@" ;;
        *) "$e" "$@" ;;
    esac
}

EDITORS=""
if [ "$MODE" != pack ]; then
    CANDIDATES=""
    for c in $NATIVE; do
        command -v "$c" >/dev/null 2>&1 && CANDIDATES="$CANDIDATES $c"
    done
    if command -v flatpak >/dev/null 2>&1; then
        for f in $FLATPAK; do
            flatpak info "$f" >/dev/null 2>&1 && CANDIDATES="$CANDIDATES flatpak:$f"
        done
    fi

    SEEN=""
    for c in $CANDIDATES; do
        version=$(run_editor "$c" --version 2>/dev/null | head -n 2) || true
        printf '%s\n' "$version" | head -n 1 | grep -Eq '^[0-9]+\.[0-9]+' || continue
        product=$(run_editor "$c" --help 2>/dev/null | head -n 1) || true
        key=$(printf '%s%s' "$product" "$version" | tr -d ' \n')
        case " $SEEN " in *" $key "*) continue ;; esac
        SEEN="$SEEN $key"
        EDITORS="$EDITORS $c"
    done
fi

if [ "$MODE" = list ]; then
    for c in $EDITORS; do echo "$c"; done
    exit 0
fi
if [ -z "$EDITORS" ] && [ "$MODE" = install ]; then
    echo "No editor found (VS Code, VSCodium, Code - OSS, Cursor, Windsurf...): nothing to do."
    echo "Install vscode/quickshell-theme-sync/*.vsix by hand (see README)."
    exit 1
fi

field() {
    sed -n 's/^  "'"$1"'": *"\([^"]*\)".*/\1/p' "$EXT/package.json" | head -n 1
}
NAME=$(field name)
PUBLISHER=$(field publisher)
VERSION=$(field version)
ID="$PUBLISHER.$NAME"
VSIX="$EXT/$ID-$VERSION.vsix"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

stage="$TMP/stage"
mkdir -p "$stage/extension"
cp -R "$EXT/." "$stage/extension/"
rm -f "$stage/extension/"*.vsix
cat > "$stage/extension.vsixmanifest" <<XML
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="$NAME" Version="$VERSION" Publisher="$PUBLISHER"/>
    <DisplayName>Quickshell Theme Sync</DisplayName>
    <Description xml:space="preserve">Quickshell themes and theme sync</Description>
    <Categories>Themes</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.60.0"/>
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
XML
cat > "$stage/[Content_Types].xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".md" ContentType="text/markdown"/><Default Extension=".vsixmanifest" ContentType="text/xml"/></Types>
XML
if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in sorted(files):
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, src))' "$stage" "$TMP/new.vsix"
elif command -v bsdtar >/dev/null 2>&1; then
    (cd "$stage" && bsdtar -a -cf "$TMP/new.vsix" ./*)
elif command -v zip >/dev/null 2>&1; then
    (cd "$stage" && zip -qr "$TMP/new.vsix" .)
else
    echo "  ! python3, bsdtar or zip needed to pack the extension"
    exit 1
fi
rm -f "$EXT"/*.vsix
mv "$TMP/new.vsix" "$VSIX"
echo "packed ${VSIX#"$SRC"/}"
[ "$MODE" = pack ] && exit 0

FAILED=0
for CODE in $EDITORS; do
    if run_editor "$CODE" --install-extension "$VSIX" --force >"$TMP/log" 2>&1 \
        && run_editor "$CODE" --list-extensions 2>/dev/null | grep -qix "$ID"; then
        echo "  $CODE: $ID $VERSION installed"
    else
        echo "  ! $CODE: could not install $ID:"
        sed 's/^/      /' "$TMP/log"
        echo "    install it by hand: ${VSIX#"$SRC"/} (see README)"
        FAILED=1
    fi
done

echo "Done. Restart the editor (or run \"Developer: Reload Window\") to load it."
exit "$FAILED"
