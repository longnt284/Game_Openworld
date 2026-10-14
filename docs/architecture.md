# Kiến trúc

Godot 4.7.2, GDScript có kiểu tĩnh, renderer GL Compatibility, bàn phím + chuột, mục tiêu Windows desktop. Không dùng autoload: `scenes/main.tscn` chỉ có node gốc `main.gd`, mọi hệ thống được tạo bằng code và nối với nhau ở đó. Nội dung (nhiệm vụ, hội thoại, vật phẩm, địch, bản đồ) nằm trong JSON dưới `data/`, code chỉ chứa luật.

## Thành phần

| Nhóm | File | Trách nhiệm |
|---|---|---|
| Gốc | `scripts/main.gd` | Luồng màn hình chính → chơi; nối người chơi, thế giới, thực thể, nhiệm vụ, hội thoại, UI, âm thanh; phần thưởng, chết/hồi sinh, lưu/tải, thoát game |
| Dữ liệu | `scripts/core/content_db.gd`, `game_state.gd`, `user_settings.gd` | Đọc JSON có cache; trạng thái người chơi (cờ, túi đồ, nhiệm vụ, cấp, kỹ năng, kiếm, checkpoint); thiết lập lưu riêng ở `user://settings.cfg` |
| Người chơi | `scripts/player_controller.gd`, `scripts/player/camera_rig.gd` | Máy trạng thái loading/move/dodge/action/hit/dead/disabled, đệm phím, thể lực, khinh công, khóa mục tiêu; camera SpringArm có rung theo "trauma" |
| Chiến đấu | `scripts/combat/combat.gd`, `projectile.gd`, `vfx.gd` | Bảng đòn đánh (gộp thời điểm từ `data/anim_timings.json`), quét cung bằng `PhysicsShapeQueryParameters3D`, gói sát thương, lớp va chạm, đạn gió, hiệu ứng |
| Nhân vật | `scripts/characters/character_visual.gd` | Dựng `AnimationTree` (BlendSpace1D di chuyển, Transition trạng thái, OneShot đòn đánh), gắn vũ khí vào `BoneAttachment3D`, nháy trắng khi trúng đòn, hit-stop |
| Địch | `scripts/enemies/enemy.gd`, `boar.gd`, `guardian.gd` | AI theo trạng thái, giới hạn số kẻ tấn công cùng lúc mỗi trại, NavigationAgent hoặc lái tránh vật cản, kéo về khi đi quá xa; heo húc; Trúc Tướng hai pha |
| Thế giới | `scripts/world/world_layout.gd`, `scripts/world_manager.gd`, `scripts/world_chunk.gd` | Hàm độ cao/màu/vùng từ `layout.json`; stream vùng 32 m (5 × 5 quanh người chơi), tính mesh trên `WorkerThreadPool`, dựng node trên main thread |
| Thực thể | `scripts/world/entity_spawner.gd`, `npc.gd`, `interactable.gd`, `arena.gd`, `prop_placer.gd`, `water_bodies.gd`, `backdrop.gd` | Sinh/hủy NPC, địch, vật tương tác theo khoảng cách và điều kiện; trigger, điểm khám phá, bake navmesh theo vùng giao tranh; đấu trường; đạo cụ; sông suối; núi nền |
| Nhiệm vụ | `scripts/quests/quest_manager.gd` | Bắt đầu/tiến độ/hoàn thành theo sự kiện chuỗi (`talk:`, `reach:`, `kill:`, `interact:`, `camp_clear:`, `flag:`, `have:`…), điều kiện, điểm đánh dấu |
| Giao diện | `scripts/game_hud.gd`, `scripts/ui/menus.gd`, `map_view.gd`, `ui_theme.gd` | HUD, hội thoại, thị kiến, la bàn mục tiêu; màn hình chính, tạm dừng, bản đồ, nhật ký, túi đồ, thiết lập, ghi công |
| Âm thanh | `scripts/audio/audio_director.gd` | Bus Music/SFX/Ambience/UI, chuyển nhạc theo vùng và mức chiến đấu, âm nền, tiếng sông theo khoảng cách, pool phát 2D/3D có biến thể |
| Hình ảnh | `scripts/render/toon.gd`, `atmosphere.gd`, `shaders/*.gdshader` | Shader toon (bậc sáng, viền rim, nhiễu nét vẽ, cây đung đưa), outline đảo mặt, nước, bầu trời, tường gió; sương/nắng theo vùng |
| Lưu game | `scripts/save_store.gd` | JSON schema v2, kiểm tra kiểu, migrate v1, ghi qua `.tmp`, giữ `.bak` |

## Quy ước

- 1 đơn vị = 1 m, Y hướng lên. Model nhìn về +Z; `rotation.y = yaw`, hướng mặt `(sin yaw, 0, cos yaw)`.
- Lớp va chạm: 1 thế giới, 2 người chơi, 4 địch, 8 NPC, 16 hurtbox người chơi, 32 hurtbox địch, 64 vật tương tác.
- Mỗi thực thể có ID ổn định trong `data/world/entities.json`. `EntitySpawner` giữ tối đa một node mỗi ID; địch chết vĩnh viễn (`dead:<id>`), rương đã mở (`opened:<id>`), phần thưởng đã nhận (`reward:<quest>`) đều là cờ trong `GameState`, nên stream lại vùng hay tải save không nhân đôi NPC, hồi sinh boss hoặc trả thưởng lần hai.
- Thời điểm đòn đánh (độ dài, khung gây sát thương, khung nối đòn, khung bất tử) chỉ định nghĩa một lần trong `data/anim_timings.json`; script Blender đọc nó để đặt keyframe, game đọc nó để xử lý va chạm.

## Thế giới và streaming

- Bản đồ hữu hạn, biên x ∈ [−132, 132], z ∈ [−462, 100]; ngoài biên là tường vô hình và núi nền.
- Độ cao = đường cong theo z + nhiễu + nâng mép (bão hòa bằng `tanh`) + sống núi → làm phẳng khu đặt nhà/đấu trường → hạ đường đi → lòng sông → khe vực. Mép vùng khớp nhau vì mọi đỉnh lấy từ tọa độ thế giới.
- `WorldChunk.compute()` là hàm tĩnh, không chạm scene tree, chạy trên `WorkerThreadPool` (tối đa 2 việc). `apply()` tạo mesh, collider, MultiMesh cây/cỏ/đá trên main thread. Người chơi đứng yên khi vùng dưới chân chưa sẵn sàng.
- Navmesh không phủ toàn bản đồ: mỗi khu giao tranh (`navzone`) được parse collider đã stream và bake bất đồng bộ khi người chơi đến gần 80 m.

## Lưu game

`user://world_save.json`, schema v2: seed, vị trí, hướng, checkpoint, toàn bộ `GameState`. Giới hạn 1 MiB (thay cho 16 KB của bản nền — dữ liệu cờ/nhiệm vụ lớn hơn nhiều). Save v1 của bản nền được migrate (trạm đèn → Miếu Gió làng, gắn cờ `migrated_from_v1`), bản cũ giữ trong `.bak`. Tải save sửa lỗi vị trí nằm trong nước/vực/ngoài biên về checkpoint.

## Mở rộng

1. Hồi 3: thêm vùng `den_tich_phong` vào `layout.json`, thực thể và nhiệm vụ vào JSON; địch bắn xa và địch khiên dùng lại `Enemy` với lớp con như `Boar`.
2. Nếu bản đồ lớn hơn nhiều: origin shifting, navmesh theo vùng stream thay vì theo khu giao tranh.
3. Gamepad: thêm sự kiện joypad vào `UserSettings.REBINDABLE` và camera stick phải.
