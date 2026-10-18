#!/usr/bin/env sh
# Builds the static web version into build/web. Used by Vercel (vercel.json buildCommand)
# and by tools/run.sh web. Needs only curl, python3 and coreutils.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-$(sh "$ROOT/tools/setup.sh" --web | tail -n 1)}
OUT="$ROOT/build/web"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT" --import
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"
for file in index.html index.js index.wasm index.pck; do
  [ -s "$OUT/$file" ] || { echo "web export is missing $file" >&2; exit 1; }
done
du -sh "$OUT"
