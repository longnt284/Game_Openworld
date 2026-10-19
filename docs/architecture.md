# Kiến trúc

Godot 4.7.2, GDScript có kiểu tĩnh, renderer GL Compatibility (một renderer cho cả hai nền tảng), bàn phím + chuột, mục tiêu Windows desktop và trình duyệt (bản Web không luồng, host tĩnh trên Vercel). Không dùng autoload: `scenes/main.tscn` chỉ có node gốc `main.gd`, mọi hệ thống được tạo bằng code và nối với nhau ở đó. Nội dung (nhiệm vụ, hội thoại, vật phẩm, địch, bản đồ) nằm trong JSON dưới `data/`, code chỉ chứa luật.

## Thành phần

| Nhóm | File | Trách nhiệm |
|---|---|---|
| Gốc | `scripts/main.gd` | Luồng màn hình chính → chơi; nối người chơi, thế giới, thực thể, nhiệm vụ, hội thoại, UI, âm thanh; phần thưởng, chết/hồi sinh, lưu/tải, thoát game |
| Dữ liệu | `scripts/core/content_db.gd`, `game_state.gd`, `user_settings.gd`, `consumables.gd` | Đọc JSON có cache; trạng thái người chơi (cờ, túi đồ, ô vật phẩm nhanh, nhiệm vụ, cấp, kỹ năng, kiếm, cảnh giới, checkpoint); thiết lập lưu riêng ở `user://settings.cfg`; preset chất lượng Thấp/Trung bình/Cao; luật vật phẩm tiêu hao và quầy hàng |
| Hồ sơ & dài hạn | `scripts/core/player_profile.gd`, `player_stats.gd`, `gacha.gd`, `missions.gd` | Hồ sơ dùng chung mọi bản lưu (`user://profile.json`): tiền, bảo hiểm, kho kiếm, trang phục, kỷ lục Ải, nhiệm vụ ngày, trạng thái RNG; gộp chỉ số kiếm + phúc lành; quay Kỳ Ngộ và mở rương; nhiệm vụ ngày và điểm danh. Các hàm tĩnh, không chạm scene tree |
| Người chơi | `scripts/player_controller.gd`, `scripts/player/camera_rig.gd` | Máy trạng thái loading/move/dodge/action/hit/dead/disabled, đệm phím, thể lực, khinh công, khóa mục tiêu; camera SpringArm có rung theo "trauma" |
| Chiến đấu | `scripts/combat/combat.gd`, `style_book.gd`, `skill_runner.gd`, `area_effect.gd`, `status_effects.gd`, `projectile.gd`, `vfx.gd`, `sword_trail.gd` | Bảng đòn đánh từ `data/attacks.json` (gộp thời điểm từ `data/anim_timings.json`), quét cung bằng `PhysicsShapeQueryParameters3D`, gói sát thương mang nguyên tố và trạng thái; 5 hệ kiếm E/Q/X chạy theo trường `kind` (sweep, dash, projectile, chain, strikes, nova, field); trạng thái gió/ướt/tê/thiêu/lạnh/đóng băng, cùng luật cho buff/debuff trên người chơi (trúng độc, chảy máu, choáng, suy nhược, lãng quên, 5 buff) và `enemy_rage` phe địch; đạn, hiệu ứng, vệt kiếm |
| Nhân vật | `scripts/characters/character_visual.gd` | Dựng `AnimationTree` (BlendSpace1D di chuyển, Transition trạng thái, OneShot đòn đánh), gắn vũ khí vào `BoneAttachment3D`, nháy trắng khi trúng đòn, hit-stop |
| Địch | `scripts/enemies/enemy.gd`, `boar.gd`, `guardian.gd`, `enemy_scaler.gd`, `enemy_factory.gd` | Một chỗ chọn lớp địch theo trường `class` trong `enemies.json`; AI theo trạng thái, giới hạn số kẻ tấn công cùng lúc mỗi trại (`max_attackers`, mặc định 2, boss bỏ qua), đổi màu theo `tint`, NavigationAgent hoặc lái tránh vật cản, kéo về khi đi quá xa; heo húc; Trúc Tướng hai pha; tăng sức mạnh theo cảnh giới/đợt và biến thành tinh anh trên bản sao dữ liệu riêng |
| Thế giới | `scripts/world/world_layout.gd`, `scripts/world_manager.gd`, `scripts/world_chunk.gd` | Hàm độ cao/màu/vùng từ `layout.json`; stream vùng 32 m (5 × 5 quanh người chơi, preset Cao 7 × 7), tính mesh và rải thực vật theo `data/world/flora.json` trên `WorkerThreadPool`, dựng node trên main thread |
| Thực thể | `scripts/world/entity_spawner.gd`, `npc.gd`, `interactable.gd`, `arena.gd`, `prop_placer.gd`, `water_bodies.gd`, `backdrop.gd`, `trial_director.gd` | Sinh/hủy NPC, địch, vật tương tác theo khoảng cách và điều kiện (theo cảnh giới: `tier_dead:<cấp>:<id>`); trigger, điểm khám phá, bake navmesh theo vùng giao tranh; đấu trường; đạo cụ; sông suối; núi đá vôi nền; Ải Vô Tận (đợt, phúc lành, rương) |
| Nhiệm vụ | `scripts/quests/quest_manager.gd` | Bắt đầu/tiến độ/hoàn thành theo sự kiện chuỗi (`talk:`, `reach:`, `kill:`, `interact:`, `camp_clear:`, `flag:`, `have:`…), điều kiện, điểm đánh dấu |
| Giao diện | `scripts/game_hud.gd`, `scripts/ui/menus.gd`, `retention_panels.gd`, `shop_panel.gd`, `map_view.gd`, `ui_theme.gd` | HUD (3 ô E/Q/X, nộ khí, số thuốc R và ô nhanh C), hội thoại, thị kiến, la bàn mục tiêu; màn hình chính, tạm dừng, bản đồ, nhật ký, túi đồ (Dùng / Đặt vào ô nhanh), thiết lập, ghi công; Kỳ Ngộ, kho kiếm & trang phục, nhiệm vụ ngày, cảnh giới, chọn phúc lành; quầy thuốc |
| Âm thanh | `scripts/audio/audio_director.gd` | Bus Music/SFX/Ambience/UI, chuyển nhạc theo vùng và mức chiến đấu, âm nền, tiếng sông theo khoảng cách, pool phát 2D/3D có biến thể |
| Hình ảnh | `scripts/render/toon.gd`, `atmosphere.gd`, `ambient_fx.gd`, `shaders/*.gdshader` | Shader toon (bậc sáng, viền rim, nhiễu nét vẽ, màu đỉnh/instance, nắng lốm đốm dưới tán, cây đung đưa), outline đảo mặt, nước fresnel có bọt, trời mây cel, núi nền, tường gió; sương theo độ sâu/độ cao, glow, chỉnh màu; hạt bay theo vùng |
| Lưu game | `scripts/save_store.gd` | JSON schema v3, kiểm tra kiểu, migrate v1/v2, ghi qua `.tmp`, giữ `.bak`; cùng cơ chế cho hồ sơ |

## Quy ước

- 1 đơn vị = 1 m, Y hướng lên. Model nhìn về +Z; `rotation.y = yaw`, hướng mặt `(sin yaw, 0, cos yaw)`.
- Lớp va chạm: 1 thế giới, 2 người chơi, 4 địch, 8 NPC, 16 hurtbox người chơi, 32 hurtbox địch, 64 vật tương tác.
- Mỗi thực thể có ID ổn định trong `data/world/entities.json`. `EntitySpawner` giữ tối đa một node mỗi ID; địch chết vĩnh viễn (`dead:<id>`), rương đã mở (`opened:<id>`), phần thưởng đã nhận (`reward:<quest>`) đều là cờ trong `GameState`, nên stream lại vùng hay tải save không nhân đôi NPC, hồi sinh boss hoặc trả thưởng lần hai.
- Thời điểm đòn đánh (độ dài, khung gây sát thương, khung nối đòn, khung bất tử) chỉ định nghĩa một lần trong `data/anim_timings.json`; script Blender đọc nó để đặt keyframe, game đọc nó để xử lý va chạm.

## Thế giới và streaming

- Bản đồ hữu hạn, biên x ∈ [−132, 132], z ∈ [−462, 100]; ngoài biên là tường vô hình và núi nền.
- Độ cao = đường cong theo z + nhiễu + nâng mép (bão hòa bằng `tanh`) + sống núi → làm phẳng khu đặt nhà/đấu trường → hạ đường đi → lòng sông → khe vực. Mép vùng khớp nhau vì mọi đỉnh lấy từ tọa độ thế giới.
- `WorldChunk.compute()` là hàm tĩnh, không chạm scene tree, chạy trên `WorkerThreadPool` (tối đa 2 việc; bản Web không luồng chạy tuần tự từng việc mỗi khung). Mỗi loài cây có RNG riêng nên đổi preset chỉ làm thưa cỏ hoa, cây có collider không dời chỗ; vùng cấm quanh NPC/rương/miếu/đạo cụ (`keepouts`). `apply()` tạo mesh, collider, MultiMesh cây/cỏ/đá trên main thread. Người chơi đứng yên khi vùng dưới chân chưa sẵn sàng.
- Navmesh không phủ toàn bản đồ: mỗi khu giao tranh (`navzone`) được parse collider đã stream và bake bất đồng bộ khi người chơi đến gần 80 m.

## Lưu game

`user://world_save.json`, schema v3: seed, vị trí, hướng, checkpoint, toàn bộ `GameState` (thêm danh sách kiếm, kiếm kho đang dùng, cảnh giới hiện tại/cao nhất). Giới hạn 1 MiB. Save v1 của bản nền và v2 đều được migrate, bản cũ giữ trong `.bak`. Tải save sửa lỗi vị trí nằm trong nước/vực/ngoài biên/đấu trường Ải về checkpoint. Trên web, `user://` là IndexedDB; game tự lưu mỗi 60 giây và khi mất focus.

`user://profile.json` (hồ sơ v1) dùng chung cho mọi bản lưu vì Kỳ Ngộ mở được từ màn hình chính trước khi tải save. RNG của gacha lưu seed/state dạng chuỗi (số 64 bit), nên tải lại không quay lại được kết quả. Test luôn dùng `profile_path` riêng, không chạm hồ sơ thật.

## Hệ thống dài hạn

- **Chỉ số:** `PlayerStats.compute(kiếm kho, phúc lành)` → `GameState.stats`; rỗng là trung tính, nên số liệu cốt truyện giữ nguyên. Đọc trong `attack_power()`, `PlayerController.strike` (bạo kích, đòn thường, nguyên tố, tỉ lệ trạng thái, nộ khí), `_try_skill` (hồi chiêu), `take_damage` (giảm sát thương), `move_speed_scale` (tốc chạy). `GameState.stat` cộng thêm `status_stats` — trường `stats` của các trạng thái đang có trên người chơi, do `PlayerController` đẩy vào mỗi khi danh sách đổi (không lưu).
- **Trạng thái người chơi:** `PlayerController.statuses` là một `StatusEffects` như của địch, tick mỗi khung vật lý khi còn sống. Luật trong `data/elements.json` `statuses`: `kind` (element/buff/debuff), `stats`, `dot_max_hp`/`regen_max_hp` (theo máu tối đa), `blocks_regen`, `shed_on_dodge`, `stun`, `hint`. Đòn địch trúng sạch roll `damage.status` (đỡ: nửa tỉ lệ; né/phản: không bao giờ), giảm theo `status_resist` + `res_<nguyên tố>`; choáng/đóng băng dùng trạng thái `hit`; chết, hồi sinh và ván mới xóa hết. Vật phẩm gọi `apply_status` (thời hạn lấy từ vật phẩm)/`cleanse`. HUD vẽ hàng icon trên thanh máu từ `list_for_hud()`, cập nhật 10 lần/giây trong `_refresh_hud`.
- **Vật phẩm tiêu hao:** `data/items.json` mỗi món có `effect` {`heal` (phần máu tối đa), `buff` (id trạng thái), `duration`, `cleanse` [id]} và `price` (Đồng); `Consumables` (tĩnh) đọc luật, `PlayerController.consume_item` áp lên Lâm An. R lấy món hồi máu mạnh nhất (`kind` "heal", xếp theo `heal`), C dùng `GameState.quick_item` (chọn trong Túi đồ, lưu trong save, khóa tùy chọn nên schema vẫn v3); cả hai cùng động tác `interact`, trừ vật phẩm ở 0,35 s. Nút "Dùng" trong Túi đồ áp ngay nhưng bị từ chối khi đang giao chiến. Nguồn: rơi từ địch (`drops`), `supplies` của rương thưởng trong `gacha.json` (vào túi đồ của save, không vào hồ sơ) và quầy hàng.
- **Quầy hàng:** `data/shops.json` {id: {name, keeper, description, items: [[vật phẩm, giá hoặc null]]}}; null dùng `price` của vật phẩm. Hội thoại chạy `do: shop:<id>` mở `ShopPanel`; đóng quầy là về thẳng trò chơi. `main.buy_item` trừ Đồng (`GameState.coins`), thiếu thì báo và không đổi gì. Ông Lang Vân đứng sau sạp ở quảng trường làng. NPC có `barks` nói một câu ngẫu nhiên khi người chơi tới gần 9 m (lọc bằng `bark_if`).
- **Ải Vô Tận:** `TrialDirector` có `Arena` riêng tại "pocket" (0, 230) — một khu bằng phẳng ngoài tường biên (`WorldLayout.in_pocket`), chỉ tới được bằng dịch chuyển. Địch của Ải không nằm trong `EntitySpawner`, nên không ghi `dead:`/`camp_kills`. Chết trong Ải rẽ nhánh ở `_on_player_died`; lưu bị từ chối trong lượt.
- **Cảnh giới:** `on_enemy_spawned` gọi `EnemyScaler` với hệ số từ `world_tiers.json`; boss dùng `boss_alive()` theo cấp.
- **Gacha:** `Gacha.roll` là hàm thuần trên bản ghi bảo hiểm; tỉ lệ tổng hợp tính giải tích (`consolidated_ssr`) để công khai và để test 200.000 lượt đối chiếu.

## Mở rộng

1. Hồi 3: thêm vùng `den_tich_phong` vào `layout.json`, thực thể và nhiệm vụ vào JSON; địch bắn xa và địch khiên dùng lại `Enemy` với lớp con như `Boar`, đăng ký trong `EnemyFactory.CLASSES`; đòn vùng của địch dùng `AreaEffect` với mặt nạ `LAYER_HURT_PLAYER`; tiếng vung đòn lấy từ `start_sfx` trong `attacks.json`.
2. Nếu bản đồ lớn hơn nhiều: origin shifting, navmesh theo vùng stream thay vì theo khu giao tranh.
3. Gamepad: thêm sự kiện joypad vào `UserSettings.REBINDABLE` và camera stick phải.
