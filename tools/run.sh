#!/usr/bin/env sh
# Linux/macOS helper. GODOT points to a Godot 4.7.2 binary (default: godot on PATH).
# Usage: tools/run.sh [game|editor|test|preview|export]
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-godot}
MODE=${1:-game}
case "$MODE" in
  test)
    "$GODOT" --headless --path "$ROOT" --editor --import
    "$GODOT" --headless --render-thread safe --path "$ROOT" --script res://tests/smoke_test.gd
    "$GODOT" --headless --render-thread safe --path "$ROOT" --script res://tests/gameplay_test.gd
    ;;
  preview)
    "$GODOT" --path "$ROOT" --resolution 1920x1080 --script res://tests/render_preview.gd
    ;;
  export)
    mkdir -p "$ROOT/build/windows"
    "$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$ROOT/build/windows/VanKhe.exe"
    ;;
  editor)
    "$GODOT" --path "$ROOT" --editor
    ;;
  *)
    "$GODOT" --path "$ROOT"
    ;;
esac
