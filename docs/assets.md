# Danh mục asset

Sinh tự động bằng `python3 tools/asset_manifest.py` từ các file thật trong `assets/`. Số tam giác đọc từ GLB (không tính mesh va chạm `-colonly`/`-convcolonly`, ghi riêng ở cột Va chạm). Không có texture ảnh nhúng: màu nằm ở vertex color/material, shader toon của game tô bóng.

## Model 3D

| File | Trạng thái | Nguồn tạo | File nguồn | Tris | Va chạm | Vật liệu | Texture | Xương | Animation |
|---|---|---|---|---:|---:|---:|---:|---:|---|
| `assets/models/beacon.glb` | Legacy (bản nền cũ, runtime không dùng) | `tools/blender/build_assets.py` | `art/beacon.blend` | 218 | 0 | 3 | 0 | — | — |
| `assets/models/characters/ba_hanh.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/ba_hanh.blend` | 6,428 | 0 | 4 | 0 | 20 | idle, talk, walk, wave |
| `assets/models/characters/ba_luc.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/ba_luc.blend` | 6,264 | 0 | 3 | 0 | 20 | idle, talk, walk, wave |
| `assets/models/characters/chu_bay.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/chu_bay.blend` | 6,766 | 0 | 6 | 0 | 20 | idle, talk, walk, wave, work |
| `assets/models/characters/cung_thu.glb` | Dùng trong slice | `tools/blender/build_monsters.py` | `art/characters/cung_thu.blend` | 7,142 | 0 | 1 | 0 | 20 | alert, bash, death, hit, hop, idle, run, shoot, stagger, walk |
| `assets/models/characters/heo_gio.glb` | Dùng trong slice | `tools/blender/build_creatures.py` | `art/characters/heo_gio.blend` | 1,346 | 0 | 6 | 0 | 12 | charge, death, hit, idle, run, stagger, walk, windup |
| `assets/models/characters/ho_ve.glb` | Dùng trong slice | `tools/blender/build_monsters.py` | `art/characters/ho_ve.blend` | 10,498 | 0 | 2 | 0 | 20 | alert, bash, block, death, hit, idle, run, stagger, thrust, walk |
| `assets/models/characters/hon_anh.glb` | Dùng trong slice | `tools/blender/build_monsters.py` | `art/characters/hon_anh.blend` | 6,394 | 0 | 2 | 0 | 20 | alert, blink, claw, death, hit, idle, run, scream, stagger, walk |
| `assets/models/characters/khoi_loi.glb` | Dùng trong slice | `tools/blender/build_monsters.py` | `art/characters/khoi_loi.blend` | 4,102 | 0 | 2 | 0 | 20 | alert, awaken, death, hit, idle, punch, roar, run, slam, stagger, throw, walk |
| `assets/models/characters/lam_an.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/lam_an.blend` | 8,718 | 0 | 6 | 0 | 20 | air_leap, attack_1, attack_2, attack_3, block, dash_slash, death, dodge, fall, glide, heavy, hit, idle, interact, jump, land, parry, run, skill_cyclone, skill_gust, ultimate, walk |
| `assets/models/characters/phap_su.glb` | Dùng trong slice | `tools/blender/build_monsters.py` | `art/characters/phap_su.blend` | 6,814 | 0 | 2 | 0 | 20 | alert, blink, cast, death, hit, idle, run, stagger, storm, walk |
| `assets/models/characters/soi_chua.glb` | Dùng trong slice | `tools/blender/build_monsters.py` | `art/characters/soi_chua.blend` | 3,762 | 0 | 2 | 0 | 16 | alert, bite, death, hit, howl, idle, pounce, run, stagger, walk |
| `assets/models/characters/soi_suong.glb` | Dùng trong slice | `tools/blender/build_monsters.py` | `art/characters/soi_suong.blend` | 2,760 | 0 | 2 | 0 | 16 | alert, bite, death, hit, howl, idle, pounce, run, stagger, walk |
| `assets/models/characters/tan_binh.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/tan_binh.blend` | 7,656 | 0 | 1 | 0 | 20 | alert, attack, death, hit, idle, run, stagger, walk |
| `assets/models/characters/tich_phong.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/tich_phong.blend` | 6,368 | 0 | 2 | 0 | 20 | idle, talk, walk, wave |
| `assets/models/characters/tieu_mac.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/tieu_mac.blend` | 7,502 | 0 | 3 | 0 | 20 | idle, talk, walk, wave |
| `assets/models/characters/truc_tuong.glb` | Dùng trong slice | `tools/blender/build_characters.py` | `art/characters/truc_tuong.blend` | 9,670 | 0 | 2 | 0 | 20 | attack, death, hit, idle, roar, slam, stagger, sweep, walk |
| `assets/models/env/bamboo_cluster.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/bamboo_cluster.blend` | 2,130 | 0 | 1 | 0 | — | — |
| `assets/models/env/bamboo_far.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/bamboo_far.blend` | 50 | 0 | 1 | 0 | — | — |
| `assets/models/env/barrel.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/barrel.blend` | 232 | 28 | 1 | 0 | — | — |
| `assets/models/env/basket_produce.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/basket_produce.blend` | 796 | 0 | 1 | 0 | — | — |
| `assets/models/env/bench.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/bench.blend` | 68 | 12 | 1 | 0 | — | — |
| `assets/models/env/boat.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/boat.blend` | 448 | 0 | 1 | 0 | — | — |
| `assets/models/env/bridge_wood.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/bridge_wood.blend` | 1,272 | 120 | 1 | 0 | — | — |
| `assets/models/env/bush_flower.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/bush_flower.blend` | 1,280 | 0 | 1 | 0 | — | — |
| `assets/models/env/bush_round.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/bush_round.blend` | 1,100 | 0 | 1 | 0 | — | — |
| `assets/models/env/campfire.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/campfire.blend` | 378 | 0 | 2 | 0 | — | — |
| `assets/models/env/chest.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/chest.blend` | 148 | 12 | 1 | 0 | — | — |
| `assets/models/env/crate.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/crate.blend` | 96 | 12 | 1 | 0 | — | — |
| `assets/models/env/dock.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/dock.blend` | 1,020 | 12 | 1 | 0 | — | — |
| `assets/models/env/fence_bamboo.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/fence_bamboo.blend` | 224 | 12 | 1 | 0 | — | — |
| `assets/models/env/fern_clump.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/fern_clump.blend` | 112 | 0 | 1 | 0 | — | — |
| `assets/models/env/flower_patch.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/flower_patch.blend` | 192 | 0 | 1 | 0 | — | — |
| `assets/models/env/flower_pot.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/flower_pot.blend` | 728 | 0 | 1 | 0 | — | — |
| `assets/models/env/gate_tam_quan.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/gate_tam_quan.blend` | 4,680 | 112 | 1 | 0 | — | — |
| `assets/models/env/gate_village.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/gate_village.blend` | 2,428 | 56 | 2 | 0 | — | — |
| `assets/models/env/grass_tuft.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/grass_tuft.blend` | 78 | 0 | 1 | 0 | — | — |
| `assets/models/env/haystack.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/haystack.blend` | 214 | 28 | 1 | 0 | — | — |
| `assets/models/env/house_long.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/house_long.blend` | 11,508 | 12 | 2 | 0 | — | — |
| `assets/models/env/house_small.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/house_small.blend` | 6,656 | 12 | 2 | 0 | — | — |
| `assets/models/env/house_teal.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/house_teal.blend` | 7,304 | 12 | 2 | 0 | — | — |
| `assets/models/env/incense_burner.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/incense_burner.blend` | 748 | 28 | 1 | 0 | — | — |
| `assets/models/env/karst_peak.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/karst_peak.blend` | 2,992 | 0 | 1 | 0 | — | — |
| `assets/models/env/lantern_post.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/lantern_post.blend` | 334 | 28 | 2 | 0 | — | — |
| `assets/models/env/lantern_stone.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/lantern_stone.blend` | 214 | 12 | 2 | 0 | — | — |
| `assets/models/env/lantern_string.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/lantern_string.blend` | 1,670 | 56 | 2 | 0 | — | — |
| `assets/models/env/log_fallen.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/log_fallen.blend` | 108 | 0 | 1 | 0 | — | — |
| `assets/models/env/market_stall.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/market_stall.blend` | 2,256 | 12 | 1 | 0 | — | — |
| `assets/models/env/memory_stone.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/memory_stone.blend` | 126 | 28 | 2 | 0 | — | — |
| `assets/models/env/mushroom_cluster.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/mushroom_cluster.blend` | 232 | 0 | 1 | 0 | — | — |
| `assets/models/env/pagoda_bell_tower.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/pagoda_bell_tower.blend` | 6,382 | 12 | 1 | 0 | — | — |
| `assets/models/env/pebbles.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/pebbles.blend` | 216 | 0 | 1 | 0 | — | — |
| `assets/models/env/prayer_banner.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/prayer_banner.blend` | 192 | 28 | 1 | 0 | — | — |
| `assets/models/env/reed_clump.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/reed_clump.blend` | 130 | 0 | 1 | 0 | — | — |
| `assets/models/env/rice_rack.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/rice_rack.blend` | 320 | 12 | 1 | 0 | — | — |
| `assets/models/env/rock_cliff.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/rock_cliff.blend` | 880 | 12 | 1 | 0 | — | — |
| `assets/models/env/rock_moss.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/rock_moss.blend` | 90 | 0 | 1 | 0 | — | — |
| `assets/models/env/ruins_pillar.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/ruins_pillar.blend` | 176 | 28 | 1 | 0 | — | — |
| `assets/models/env/ruins_wall.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/ruins_wall.blend` | 936 | 12 | 1 | 0 | — | — |
| `assets/models/env/seal_gate.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/seal_gate.blend` | 2,988 | 24 | 2 | 0 | — | — |
| `assets/models/env/shrine_wind.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/shrine_wind.blend` | 1,228 | 36 | 2 | 0 | — | — |
| `assets/models/env/signboard.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/signboard.blend` | 176 | 12 | 1 | 0 | — | — |
| `assets/models/env/smithy.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/smithy.blend` | 4,732 | 136 | 2 | 0 | — | — |
| `assets/models/env/stele.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/stele.blend` | 280 | 12 | 1 | 0 | — | — |
| `assets/models/env/steps_stone.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/steps_stone.blend` | 264 | 12 | 1 | 0 | — | — |
| `assets/models/env/stone_nghe.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/stone_nghe.blend` | 908 | 12 | 1 | 0 | — | — |
| `assets/models/env/table.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/table.blend` | 184 | 12 | 1 | 0 | — | — |
| `assets/models/env/tent.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/tent.blend` | 84 | 12 | 1 | 0 | — | — |
| `assets/models/env/tree_blossom.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/tree_blossom.blend` | 1,392 | 0 | 1 | 0 | — | — |
| `assets/models/env/tree_maple.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/tree_maple.blend` | 1,376 | 0 | 1 | 0 | — | — |
| `assets/models/env/tree_pine.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/tree_pine.blend` | 152 | 0 | 1 | 0 | — | — |
| `assets/models/env/tree_round.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/tree_round.blend` | 1,832 | 0 | 1 | 0 | — | — |
| `assets/models/env/watchtower.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/watchtower.blend` | 2,216 | 12 | 1 | 0 | — | — |
| `assets/models/env/well.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/well.blend` | 2,932 | 36 | 1 | 0 | — | — |
| `assets/models/env/wind_chime_post.glb` | Dùng trong slice | `tools/blender/build_props.py` | `art/env/wind_chime_post.blend` | 228 | 28 | 1 | 0 | — | — |
| `assets/models/rock.glb` | Legacy (bản nền cũ, runtime không dùng) | `tools/blender/build_assets.py` | `art/rock.blend` | 20 | 0 | 1 | 0 | — | — |
| `assets/models/tree.glb` | Legacy (bản nền cũ, runtime không dùng) | `tools/blender/build_assets.py` | `art/tree.blend` | 60 | 0 | 4 | 0 | — | — |
| `assets/models/weapons/glaive.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/glaive.blend` | 504 | 0 | 6 | 0 | — | — |
| `assets/models/weapons/sabre.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sabre.blend` | 530 | 0 | 4 | 0 | — | — |
| `assets/models/weapons/spear.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/spear.blend` | 354 | 0 | 5 | 0 | — | — |
| `assets/models/weapons/staff.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/staff.blend` | 446 | 0 | 5 | 0 | — | — |
| `assets/models/weapons/sword_bamboo.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sword_bamboo.blend` | 462 | 0 | 7 | 0 | — | — |
| `assets/models/weapons/sword_flame.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sword_flame.blend` | 648 | 0 | 5 | 0 | — | — |
| `assets/models/weapons/sword_frost.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sword_frost.blend` | 650 | 0 | 4 | 0 | — | — |
| `assets/models/weapons/sword_old.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sword_old.blend` | 688 | 0 | 6 | 0 | — | — |
| `assets/models/weapons/sword_thunder.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sword_thunder.blend` | 704 | 0 | 5 | 0 | — | — |
| `assets/models/weapons/sword_water.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sword_water.blend` | 856 | 0 | 5 | 0 | — | — |
| `assets/models/weapons/sword_wind.glb` | Dùng trong slice | `tools/blender/build_weapons.py` | `art/weapons/sword_wind.blend` | 630 | 0 | 5 | 0 | — | — |

Tổng: 88 model, 191,076 tam giác hiển thị. Mọi model của dự án được dựng bằng script Blender 5.2.2 chạy nền (`blender --background --factory-startup --python <script>`), giấy phép: Của dự án (chủ repo chọn giấy phép).

## Âm thanh

| File | Nhóm | Nguồn | Giấy phép |
|---|---|---|---|
| `assets/audio/ambience/forest.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/ambience/night_insects.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/ambience/rain_heavy.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/ambience/rain_light.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/ambience/river.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/ambience/storm_wind.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/ambience/village.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/ambience/wind.ogg` | ambience | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/music/bamboo.ogg` | music | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/music/boss.ogg` | music | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/music/combat.ogg` | music | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/music/explore.ogg` | music | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/music/temple.ogg` | music | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/music/title.ogg` | music | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/music/village.ogg` | music | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/arrow_hit.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/barrier.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/block_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/block_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/block_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/boar_charge.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/boar_grunt.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/boar_hit_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/boar_hit_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/boar_hit_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/book.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/bow_draw.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/chest_open.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/chime_1.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/chime_2.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/chime_3.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/chime_solved.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/cloth.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/coins.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/danger.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/death.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/discovery.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/dodge.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/earth_spike.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/echo_whisper.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/enemy_down.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/flame_burst.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/flute_call.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/frost_cast.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/frost_shatter.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/ghost_wail.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/glaive_slam.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/glaive_sweep.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/glint.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/golem_grind.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/ground_slam.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/heal.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/hit_flesh_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/hit_flesh_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/hit_flesh_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/hit_heavy_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/hit_heavy_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/hit_heavy_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/jump.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/land.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/leap.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/level_up.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/parry.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/parry_metal.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/pickup.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/plank.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/quest_complete.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/roar.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/rock_crash.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/sabre_swing.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/seal_hum.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/shrine_bell.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/splash.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/step_dirt_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_dirt_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_dirt_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_dirt_3.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_dirt_4.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_grass_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_grass_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_grass_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_grass_3.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_grass_4.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_leaves_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_leaves_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_leaves_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_leaves_3.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_leaves_4.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_stone_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_stone_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_stone_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_stone_3.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_stone_4.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_wood_0.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_wood_1.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_wood_2.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_wood_3.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/step_wood_4.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/swing_0.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/swing_1.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/swing_2.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/swing_heavy.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/sword_draw.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/temple_bell.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/thunder_0.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/thunder_1.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/thunder_2.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/thunder_3.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/thunder_chain.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/thunder_dash.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/ui_click.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/ui_close.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/ui_confirm.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/ui_error.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/ui_open.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/ui_select.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |
| `assets/audio/sfx/ult_release.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/victory.ogg` | sfx | tools/audio/compose_music.py (MIDI → FluidSynth, FluidR3_GM) | Của dự án (chủ repo chọn giấy phép); soundfont MIT |
| `assets/audio/sfx/water_slash.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/water_swirl.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/wind_cyclone.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/wind_slash.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/wolf_bite.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/wolf_howl.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/wolf_snarl.ogg` | sfx | tools/audio/build_sfx.py (tổng hợp numpy/scipy) | Của dự án (chủ repo chọn giấy phép) |
| `assets/audio/sfx/wood_knock.ogg` | sfx | Kenney (kenney.nl) — Impact Sounds / RPG Audio / Interface Sounds | CC0 1.0 |

Tổng: 126 file OGG Vorbis. Nhạc được soạn bằng code (giai điệu ngũ cung Rê thứ) và render qua soundfont General MIDI; cần người nghe duyệt lại trước khi phát hành (xem `docs/progress.md`).

## Font

| File | Nguồn | Giấy phép |
|---|---|---|
| `assets/fonts/BeVietnamPro-Bold.ttf` | Be Vietnam Pro (Google Fonts) | SIL OFL 1.1 (`assets/fonts/OFL-BeVietnamPro.txt`) |
| `assets/fonts/BeVietnamPro-Medium.ttf` | Be Vietnam Pro (Google Fonts) | SIL OFL 1.1 (`assets/fonts/OFL-BeVietnamPro.txt`) |
| `assets/fonts/BeVietnamPro-Regular.ttf` | Be Vietnam Pro (Google Fonts) | SIL OFL 1.1 (`assets/fonts/OFL-BeVietnamPro.txt`) |
| `assets/fonts/BeVietnamPro-SemiBold.ttf` | Be Vietnam Pro (Google Fonts) | SIL OFL 1.1 (`assets/fonts/OFL-BeVietnamPro.txt`) |
| `assets/fonts/Lora-Variable.ttf` | Lora (Google Fonts) | SIL OFL 1.1 (`assets/fonts/OFL-Lora.txt`) |
