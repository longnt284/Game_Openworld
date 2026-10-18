#!/usr/bin/env sh
# Linux counterpart of setup.ps1: installs the pinned, checksum-verified tools into .tools/.
#   tools/setup.sh            Godot 4.7.2 (self-contained mode)
#   tools/setup.sh --web      + the no-threads web export template only (~10 MB, Range-fetched)
#   tools/setup.sh --blender  + Blender 5.2.2 for tools/blender/*.py
# Prints the Godot path on the last line.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
manifest() { python3 -I -c "import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2],{'d':d}))" "$ROOT/dependencies.json" "$1"; }
VERSION=$(manifest "d['godot']['version']")
ARCHIVE=$(manifest "d['godot']['linux_archive']")
DIR="$ROOT/.tools/godot-linux"
GODOT="$DIR/${ARCHIVE%.zip}"
mkdir -p "$DIR"
touch "$DIR/_sc_"
if [ ! -x "$GODOT" ]; then
  curl -fsSL --retry 3 -o "$DIR/godot.zip" "https://github.com/godotengine/godot/releases/download/$VERSION/$ARCHIVE"
  echo "$(manifest "d['godot']['linux_sha512']")  $DIR/godot.zip" | sha512sum -c - >/dev/null
  python3 -I -c 'import sys,zipfile;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$DIR/godot.zip" "$DIR"
  rm "$DIR/godot.zip"
  chmod +x "$GODOT"
fi
for arg in "$@"; do
  case "$arg" in
    --web)
      # Self-contained mode reads templates from editor_data/ next to the binary.
      TEMPLATES="$DIR/editor_data/export_templates/$(echo "$VERSION" | tr - .)"
      [ -f "$TEMPLATES/$(manifest "d['godot']['export_templates']['web']['file']")" ] || python3 -I "$ROOT/tools/fetch_web_template.py" "$TEMPLATES"
      ;;
    --blender)
      BLENDER_DIR="$ROOT/.tools/blender"
      if [ ! -x "$BLENDER_DIR/blender" ]; then
        mkdir -p "$BLENDER_DIR"
        curl -fsSL --retry 3 -o "$BLENDER_DIR/blender.tar.xz" "$(manifest "d['blender']['linux_url']")"
        echo "$(manifest "d['blender']['linux_sha256']")  $BLENDER_DIR/blender.tar.xz" | sha256sum -c - >/dev/null
        tar -xJf "$BLENDER_DIR/blender.tar.xz" -C "$BLENDER_DIR" --strip-components=1
        rm "$BLENDER_DIR/blender.tar.xz"
      fi
      "$BLENDER_DIR/blender" --version | head -1
      ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done
"$GODOT" --headless --version >/dev/null
echo "$GODOT"
