# Blender → Godot

Model, rig và animation được dựng bằng script Python chạy Blender 5.2.2 ở chế độ nền. Đợt nâng cấp Roblox dùng Blender MCP để kiểm tra model trong Blender, đồng thời chạy generator ở tiến trình nền riêng để bảo vệ scene đang mở. Xem [hướng mỹ thuật](roblox-art-direction.md) và [ảnh, kiểm tra, hiệu năng](visual-upgrade-progress.md).

Chạy `blender --background --factory-startup --python tools/blender/build_roblox.py -- --all` để xuất lại 76 asset đang dùng. Bỏ `--all` để dựng bộ prototype Lâm An và làng nhỏ. Chạy `python tests/art_contract.py` để so animation, skeleton và collider với commit trước nâng cấp.

| Script | Tạo ra |
|---|---|
| `tools/blender/build_characters.py` | 8 nhân vật người: Lâm An, Tiểu Mạc, bà Lục, chú Bảy, bà Hạnh, Tịch Phong, Tàn binh, Trúc Tướng — mesh, xương 20 khớp, animation |
| `tools/blender/build_creatures.py` | Heo gió (4 chân, 12 khớp) |
| `tools/blender/build_weapons.py` | Kiếm Cũ, Thanh Trúc Kiếm, Phong Ngân Kiếm, đao tàn binh, kích Trúc Tướng |
| `tools/blender/build_props.py` | Cây, trúc, cỏ, đá, nhà, cổng, miếu, cầu, bến, thuyền, đèn, rương, trại, chuông gió, cổng phong ấn… (36 asset) |
| `tools/blender/humanoid.py`, `anim_humanoid.py`, `vk_lib.py` | Thư viện chung: dựng mesh bằng bmesh, tóc/áo/mặt nạ, rig, tư thế, keyframe, bảng màu, export |
| `tools/blender/contact_sheet.py` | Ghép ảnh xem trước (Python hệ thống + Pillow) |
| `tools/blender/build_assets.py` | Bộ mẫu của bản nền (cây/đá/trạm đèn) — giữ lại, game không còn dùng |

## Chạy lại

```sh
blender --background --factory-startup --python tools/blender/build_characters.py -- lam_an --preview
blender --background --factory-startup --python tools/blender/build_props.py -- house_small dock
blender --background --factory-startup --python tools/blender/build_weapons.py
blender --background --factory-startup --python tools/blender/build_creatures.py
python3 tools/blender/contact_sheet.py lam_an 4      # ghép ảnh .cache/blender_previews/lam_an_*.png
python3 tools/asset_manifest.py                      # cập nhật docs/assets.md
./tools/run.ps1 -Mode test                           # import lại và kiểm tra
```

Không truyền tên thì script dựng tất cả. `--preview` render ảnh Workbench vào `.cache/blender_previews/` (không commit); cần OpenGL — trên Linux không màn hình hãy chạy qua `xvfb-run -a`, nếu không Blender dừng ở bước preview (GLB và `.blend` đã ghi xong trước đó). Script ghi đè file của chính nó: nếu chỉnh `.blend` bằng tay, hãy export file đó trực tiếp thay vì chạy lại generator.

## Quy ước

- Mét, Z-up trong Blender; exporter glTF chuyển sang Y-up. Nhân vật nhìn về −Y Blender (= +Z Godot), gốc ở chân.
- Không dùng texture ảnh: màu là vật liệu Principled phẳng theo bảng màu trong `vk_lib.py` (ngọc, trúc, kem, đỏ son, vàng); shader toon của Godot thay vật liệu khi nạp, giữ tên vật liệu.
- Va chạm: object tên `*-convcolonly` (hộp lồi) hoặc `*-colonly` thành `StaticBody3D` khi import; không xuất hiện khi render.
- Xương được đặt roll để trục X cục bộ là trục ngang, giúp xoay tay/chân nhất quán. Socket vũ khí (`SwordSocket` ở tay phải, `SheathSocket` ở hông) là empty gắn vào xương; glTF importer của Godot biến chúng thành `BoneAttachment3D`, game gắn kiếm vào đó và đổi qua lại khi rút/tra kiếm.
- Vũ khí: tâm chuôi ở gốc, lưỡi theo +Z Blender (= +Y cục bộ trong Godot).
- Animation export dạng action riêng (`export_animation_mode="ACTIONS"`), 30 fps. Độ dài, khung gây sát thương, khung nối đòn, khung bất tử của mọi đòn đánh đọc từ `data/anim_timings.json` — cùng file mà game dùng để xử lý va chạm, nên hình và luật luôn khớp.
- GLB vào `assets/models/{characters,weapons,env}/`, nguồn `.blend` vào `art/{characters,weapons,env}/`. `art/.gdignore` ngăn Godot import `.blend`.

## Giới hạn hiện tại

Model low-poly dựng bằng thủ tục (1–6 nghìn tam giác mỗi nhân vật), không có texture vẽ tay, không có blend shape biểu cảm. Animation là keyframe tư thế tay (không motion capture). Đủ cho vertical slice; bản phát hành nên có họa sĩ chỉnh mesh mặt/tóc và animator làm lại các đòn chính.
