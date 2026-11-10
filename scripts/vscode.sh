#!/bin/sh
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
PACK_ONLY=0
[ "${1:-}" = "--pack" ] && PACK_ONLY=1

CODE=""
for c in code codium code-oss; do
    if command -v "$c" >/dev/null 2>&1; then CODE=$c; break; fi
done
if [ -z "$CODE" ] && [ "$PACK_ONLY" = 0 ]; then
    echo "VS Code not found (code, codium or code-oss): nothing to do."
    exit 1
fi

if [ "$PACK_ONLY" = 0 ]; then
ids=$(sed -n 's/.*"extension": *"\([^"]\{1,\}\)".*/\1/p' "$SRC"/themes/*.json | sort -u)
installed=$("$CODE" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
for id in $ids; do
    low=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')
    if printf '%s\n' "$installed" | grep -qxF "$low"; then
        echo "  theme $id: already installed"
    else
        echo "  theme $id: installing"
        "$CODE" --install-extension "$id" >/dev/null 2>&1 || echo "    ! could not install $id"
    fi
done
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pack() {
    stage="$TMP/stage-$3"
    rm -rf "$stage"
    mkdir -p "$stage/extension"
    cp -R "$1". "$stage/extension/"
    rm -f "$stage/extension/generate.py" "$stage/extension/"*.vsix
    cat > "$stage/extension.vsixmanifest" <<XML
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="$3" Version="$5" Publisher="$4"/>
    <DisplayName>$3</DisplayName>
    <Description xml:space="preserve">$3</Description>
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
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".txt" ContentType="text/plain"/><Default Extension=".md" ContentType="text/markdown"/><Default Extension=".vsixmanifest" ContentType="text/xml"/></Types>
XML
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, src))' "$stage" "$2"
    elif command -v bsdtar >/dev/null 2>&1; then
        (cd "$stage" && bsdtar -a -cf "$2" ./*)
    elif command -v zip >/dev/null 2>&1; then
        (cd "$stage" && zip -qr "$2" .)
    else
        return 1
    fi
}

for dir in "$SRC"/vscode/*/; do
    [ -f "$dir/package.json" ] || continue
    name=$(sed -n 's/^ *"name": *"\([^"]*\)".*/\1/p' "$dir/package.json" | head -n 1)
    publisher=$(sed -n 's/^ *"publisher": *"\([^"]*\)".*/\1/p' "$dir/package.json" | head -n 1)
    version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$dir/package.json" | head -n 1)
    [ -n "$name" ] && [ -n "$publisher" ] && [ -n "$version" ] || continue
    vsix="${dir%/}/$publisher.$name-$version.vsix"
    if ! pack "$dir" "$TMP/new.vsix" "$name" "$publisher" "$version"; then
        echo "    ! $publisher.$name: python3, bsdtar or zip needed to pack it"
        FAILED=1
        continue
    fi
    rm -f "${dir%/}"/*.vsix
    mv "$TMP/new.vsix" "$vsix"
    if [ "$PACK_ONLY" = 1 ]; then
        echo "  packed ${vsix#"$SRC"/}"
        continue
    fi
    if "$CODE" --install-extension "$vsix" --force >"$TMP/log" 2>&1; then
        echo "  local extension $publisher.$name $version: installed"
    else
        echo "    ! could not install $publisher.$name:"
        sed 's/^/      /' "$TMP/log"
        echo "      install it by hand: ${vsix#"$SRC"/} (see README)"
        FAILED=1
    fi
done

[ "$PACK_ONLY" = 1 ] && exit "${FAILED:-0}"

if "$CODE" --list-extensions 2>/dev/null | grep -qix "local.quickshell-theme-sync"; then
    echo "  theme sync: active"
else
    echo "    ! theme sync is not listed by $CODE --list-extensions"
    FAILED=1
fi

echo "Done. Restart VS Code (or run \"Developer: Reload Window\") to load the extensions."
[ "${FAILED:-0}" = 0 ] || exit 1
