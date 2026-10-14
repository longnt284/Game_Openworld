"""Combine Blender preview frames into labelled sheets (system Python + Pillow).

python3 tools/blender/contact_sheet.py <prefix> [columns]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

PREVIEW = Path(__file__).resolve().parents[2] / ".cache" / "blender_previews"


def main(prefix, columns=8):
    frames = sorted(PREVIEW.glob(f"{prefix}_*_q.png"), key=lambda p: p.stat().st_mtime)
    if not frames:
        print("no frames for", prefix)
        return
    width, height = Image.open(frames[0]).size
    rows = (len(frames) + columns - 1) // columns
    canvas = Image.new("RGB", (width * columns, (height + 18) * rows), (30, 34, 38))
    draw = ImageDraw.Draw(canvas)
    for index, path in enumerate(frames):
        x, y = (index % columns) * width, (index // columns) * (height + 18)
        canvas.paste(Image.open(path), (x, y))
        draw.text((x + 4, y + height + 3), path.stem[len(prefix) + 1:-2], fill=(240, 230, 200))
        path.unlink()
    target = PREVIEW / f"{prefix}_anim_sheet.png"
    canvas.save(target)
    print(target)


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 8)
