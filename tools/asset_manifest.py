"""Generate docs/assets.md from the files that actually ship in assets/.

python3 tools/asset_manifest.py
Reads every GLB header (no Blender or Godot needed) and lists triangle count,
materials, embedded textures, skeleton joints and animation clips, plus the
audio and font files with their source and licence.
"""
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "assets" / "models"
AUDIO = ROOT / "assets" / "audio"
OUT = ROOT / "docs" / "assets.md"

PROJECT_LICENCE = "Của dự án (chủ repo chọn giấy phép)"
LEGACY = {"tree.glb", "rock.glb", "beacon.glb"}
SCRIPTS = {
    "characters": "tools/blender/build_characters.py",
    "weapons": "tools/blender/build_weapons.py",
    "env": "tools/blender/build_props.py",
}
KENNEY_PATTERNS = [
    r"step_(grass|wood|stone|leaves|dirt)_\d", r"hit_flesh_\d", r"block_\d", r"boar_hit_\d", r"hit_heavy_\d",
    r"parry", r"parry_metal", r"chest_open", r"coins", r"pickup", r"book", r"sword_draw", r"cloth", r"wood_knock",
    r"plank", r"ui_(click|select|open|close|confirm|error)",
]


def read_glb(path):
    data = path.read_bytes()
    magic, _version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"{path} is not a GLB file")
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError(f"{path} has no JSON chunk")
    return json.loads(data[20:20 + chunk_length])


def mesh_triangles(gltf, mesh_index):
    total = 0
    for primitive in gltf["meshes"][mesh_index]["primitives"]:
        if primitive.get("mode", 4) != 4:
            continue
        if "indices" in primitive:
            total += gltf["accessors"][primitive["indices"]]["count"] // 3
        else:
            total += gltf["accessors"][primitive["attributes"]["POSITION"]]["count"] // 3
    return total


def model_stats(path):
    gltf = read_glb(path)
    visible = 0
    collision = 0
    for node in gltf.get("nodes", []):
        if "mesh" not in node:
            continue
        tris = mesh_triangles(gltf, node["mesh"])
        if "colonly" in node.get("name", ""):
            collision += tris
        else:
            visible += tris
    joints = sum(len(skin.get("joints", [])) for skin in gltf.get("skins", []))
    clips = sorted(animation.get("name", "?") for animation in gltf.get("animations", []))
    return {
        "tris": visible,
        "collision": collision,
        "materials": len(gltf.get("materials", [])),
        "textures": len(gltf.get("images", [])),
        "joints": joints,
        "clips": clips,
    }


def model_rows():
    rows = []
    for path in sorted(MODELS.rglob("*.glb")):
        relative = path.relative_to(ROOT).as_posix()
        stats = model_stats(path)
        group = path.parent.name
        if path.name in LEGACY:
            status = "Legacy (bản nền cũ, runtime không dùng)"
            source = "tools/blender/build_assets.py"
        else:
            status = "Dùng trong slice"
            source = "tools/blender/build_creatures.py" if path.stem == "heo_gio" else SCRIPTS.get(group, "?")
        blend = ROOT / "art" / (group if group in SCRIPTS else "") / (path.stem + ".blend")
        rows.append((relative, status, source, blend.relative_to(ROOT).as_posix() if blend.exists() else "—", stats))
    return rows


def audio_rows():
    rows = []
    for path in sorted(AUDIO.rglob("*.ogg")):
        relative = path.relative_to(ROOT).as_posix()
        kind = path.parent.name
        if kind == "music" or (kind == "sfx" and _is_stinger(path.stem)):
            source, licence = "tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM)", PROJECT_LICENCE + "; soundfont MIT"
        elif kind == "sfx" and any(re.fullmatch(pattern, path.stem) for pattern in KENNEY_PATTERNS):
            source, licence = "Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds", "CC0 1.0"
        else:
            source, licence = "tools/audio/build_sfx.py (tổng hợp numpy/scipy)", PROJECT_LICENCE
        rows.append((relative, kind, source, licence))
    return rows


STINGERS = {"quest_complete", "discovery", "level_up", "victory", "death", "shrine_bell", "temple_bell", "chime_solved", "flute_call"}


def _is_stinger(stem):
    return stem in STINGERS or re.fullmatch(r"chime_\d", stem) is not None


def main():
    models = model_rows()
    audio = audio_rows()
    lines = [
        "# Danh mục asset",
        "",
        "Sinh tự động bằng `python3 tools/asset_manifest.py` từ các file thật trong `assets/`. "
        "Số tam giác đọc từ GLB (không tính mesh va chạm `-colonly`/`-convcolonly`, ghi riêng ở cột Va chạm). Không có texture ảnh nhúng: "
        "màu nằm ở vertex color/material, shader toon của game tô bóng.",
        "",
        "## Model 3D",
        "",
        "| File | Trạng thái | Nguồn tạo | File nguồn | Tris | Va chạm | Vật liệu | Texture | Xương | Animation |",
        "|---|---|---|---|---:|---:|---:|---:|---:|---|",
    ]
    total_tris = 0
    for relative, status, source, blend, stats in models:
        total_tris += stats["tris"]
        clips = ", ".join(stats["clips"]) if stats["clips"] else "—"
        lines.append(
            f"| `{relative}` | {status} | `{source}` | `{blend}` | {stats['tris']:,} | {stats['collision']:,} | "
            f"{stats['materials']} | {stats['textures']} | {stats['joints'] or '—'} | {clips} |"
        )
    lines += [
        "",
        f"Tổng: {len(models)} model, {total_tris:,} tam giác hiển thị. Mọi model của dự án được dựng bằng script "
        "Blender 5.2.2 chạy nền (`blender --background --factory-startup --python <script>`), giấy phép: "
        f"{PROJECT_LICENCE}.",
        "",
        "## Âm thanh",
        "",
        "| File | Nhóm | Nguồn | Giấy phép |",
        "|---|---|---|---|",
    ]
    for relative, kind, source, licence in audio:
        lines.append(f"| `{relative}` | {kind} | {source} | {licence} |")
    lines += [
        "",
        f"Tổng: {len(audio)} file OGG Vorbis. Nhạc được soạn bằng code (giai điệu ngũ cung Rê thứ) và render qua "
        "soundfont General MIDI; cần người nghe duyệt lại trước khi phát hành (xem `docs/progress.md`).",
        "",
        "## Font",
        "",
        "| File | Nguồn | Giấy phép |",
        "|---|---|---|",
    ]
    for path in sorted((ROOT / "assets" / "fonts").glob("*.ttf")):
        family = "Lora" if path.name.startswith("Lora") else "Be Vietnam Pro"
        licence_file = "OFL-Lora.txt" if family == "Lora" else "OFL-BeVietnamPro.txt"
        lines.append(f"| `{path.relative_to(ROOT).as_posix()}` | {family} (Google Fonts) | SIL OFL 1.1 (`assets/fonts/{licence_file}`) |")
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"MANIFEST_OK models={len(models)} tris={total_tris} audio={len(audio)}")


if __name__ == "__main__":
    main()
