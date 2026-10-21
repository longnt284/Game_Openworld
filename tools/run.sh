#!/usr/bin/env sh
# Linux/macOS helper. GODOT points to a Godot 4.7.2 binary (default: the one tools/setup.sh installs,
# then godot on PATH).
# Usage: tools/run.sh [game|editor|test|preview [scene ...]|export|web|serve|websmoke]
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [ -z "${GODOT:-}" ]; then
  GODOT="$ROOT/.tools/godot-linux/Godot_v4.7.2-stable_linux.x86_64"
  [ -x "$GODOT" ] || GODOT=godot
fi
MODE=${1:-game}
[ $# -gt 0 ] && shift
case "$MODE" in
  test)
    "$GODOT" --headless --path "$ROOT" --editor --import
    for suite in smoke_test gameplay_test combat_test progression_test world_test; do
      [ -f "$ROOT/tests/$suite.gd" ] || continue
      "$GODOT" --headless --render-thread safe --path "$ROOT" --script "res://tests/$suite.gd"
    done
    ;;
  preview)
    "$GODOT" --path "$ROOT" --resolution 1920x1080 --script res://tests/render_preview.gd -- "$@"
    ;;
  export)
    mkdir -p "$ROOT/build/windows"
    "$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$ROOT/build/windows/VanKhe.exe"
    ;;
  web)
    GODOT="$GODOT" sh "$ROOT/tools/build_web.sh"
    ;;
  serve)
    python3 -m http.server "${PORT:-8060}" --directory "$ROOT/build/web"
    ;;
  websmoke)
    node "$ROOT/tools/web_smoke.cjs" "$@"
    ;;
  editor)
    "$GODOT" --path "$ROOT" --editor
    ;;
  *)
    "$GODOT" --path "$ROOT"
    ;;
esac
