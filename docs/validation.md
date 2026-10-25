# Kết quả kiểm tra — 25/10/2026

Phân biệt rõ: **đã chạy** (có log/ảnh) và **chưa chạy được** trong môi trường phát triển.

## Môi trường đã dùng

- Linux container, Intel Xeon 2,8 GHz 4 nhân, 15 GB RAM, **không có GPU**. Render bằng Mesa llvmpipe (OpenGL 4.5, phần mềm) qua Xvfb.
- Godot `4.7.2.stable.official.ed1daf0bf` (bản Linux chính thức, cùng commit với bản Windows ghim trong `dependencies.json`), renderer GL Compatibility.
- Blender 5.2.2 LTS (chạy nền). Python 3 + Pillow, FluidSynth, ffmpeg cho công cụ nội dung.

## Kiểm thử tự động — đã chạy

| Bộ test | Lệnh | Kết quả |
|---|---|---|
| Import asset | `godot --headless --path . --editor --import` | Thành công |
| Smoke test (bản nền + thực vật, vùng cấm, preset; GĐ3: bố cục HUD không chồng nhau, vùng dựng theo lát giống hệt vùng dựng một lần, stream theo lát lấp đủ tầm nhìn, nội suy mô hình, tự hạ độ phân giải, biên dịch trước shader, HUD dưới nhường chỗ hộp hội thoại, nút màn hình chính không đè dòng ghi công) | `tests/smoke_test.gd` | **43/43 PASS** |
| Gameplay test (chơi trọn đoạn mẫu; GĐ3: Viêm Dương từ *Lò rèn nguội lửa*, 4 nhiệm vụ phụ mới mở đủ 6 hệ, navmesh dựng sẵn khớp dữ liệu và bake trực tiếp khi không có) | `tests/gameplay_test.gd` | **70/70 PASS** |
| Combat test (18 thức của 6 hệ, trạng thái, nộ khí; GĐ1: trạng thái trên người chơi, chỉ số, phản ứng, phá thế, kết liễu, Tâm Nhãn, địch dùng AoE; GĐ2: kiếm phụ; GĐ3: mở hệ theo nhiệm vụ, gắn hệ theo ô, hợp hệ +15%, Nứt giáp, 9 phản ứng, Địa Liệt Trảm trúng mỗi địch một lần, khiên đá) | `tests/combat_test.gd` | **177/177 PASS** |
| Progression test (save v4, hồ sơ, gacha, nhiệm vụ ngày, Ải Vô Tận, cảnh giới; GĐ1: vật phẩm, quầy thuốc, affix mới, Ngọc bội, hồ sơ v1 → v2; GĐ3: cầm kiếm không dạy hệ) | `tests/progression_test.gd` | **120/120 PASS** |
| World test (GĐ2: đồng hồ, thời tiết theo vùng, mức chuyển mượt, khí quyển nhiều lớp, điều kiện `time:`/`weather:`, save v4 + migrate, nghỉ ở miếu, mưa, sét, đèn đêm, âm thanh thời tiết, thời tiết trong trận) | `tests/world_test.gd` | **92/92 PASS** |
| Monster test (GĐ3: 7 quái mới — cung thủ giữ cự ly và bắn trúng, tên bay vòng cung, hộ vệ đỡ phía trước và bị trọng kích/Thổ phá khiên, lôi sư dịch chuyển và gọi sét có báo trước, sói vồ, sói đầu đàn hú tăng nộ, hồn ảnh chớp ra sau lưng và gào, khôi lỗi ngủ, thức, sang pha 2) | `tests/monster_test.gd` | **23/23 PASS** |

Tổng **525/525 PASS**. `./tools/run.ps1 -Mode test` (Windows) và `tools/run.sh test` (Linux) chạy import rồi cả sáu bộ. CI GitHub Actions chạy trên `windows-latest`.

**Combat test:** mỗi thức E/Q/X của 5 hệ khởi động, gây sát thương và gây đúng trạng thái; thiêu đốt gây sát thương theo thời gian không làm khựng; lạnh cóng làm chậm, 3 lớp thành đóng băng, boss không bị đóng băng; mục tiêu ướt chỉ nhận thêm sát thương sấm; tuyệt kỹ bị từ chối khi nộ khí chưa đầy và tiêu hết khi dùng; Phong Trảm vẫn bằng công lực × 1,6 như bản trước.

**Progression test:** 200.000 lượt quay có tỉ lệ Cực phẩm 2,44% so với tỉ lệ tổng hợp công khai 2,43%; không chuỗi nào vượt lượt bảo hiểm 70; mỗi 10 lượt có Hiếm; trượt 50/50 thì lần sau chắc chắn ra kiếm nổi bật; thiếu Ngọc bị từ chối không đổi gì; bảo hiểm và kho kiếm còn nguyên sau khi tải lại hồ sơ; trang phục trùng đổi thành Mảnh; chỉ số phụ không trùng, đúng khoảng, đúng số dòng theo độ hiếm; nhiệm vụ ngày làm mới theo ngày, thưởng nhận một lần, điểm danh đứt chuỗi khi bỏ ngày. Cảnh thật: cổng Ải đưa vào đấu trường, đợt 1 có 3 địch, không lưu được trong lượt, xong đợt thì dừng ở bảng phúc lành mà Esc không đóng được, Kiếm Phong tăng đúng 15% đòn thường, Trúc Tướng đợt 5 có máu theo hệ số đợt, gục ngã thì về cổng, nhận thưởng và không ghi cờ cốt truyện; cảnh giới 1 Trúc Tướng có 1,7 lần máu, hạ xong ghi `tier_dead:1:` và mở cảnh giới 2; tinh anh có nhãn và không sửa dữ liệu dùng chung.

**Smoke test:** nạp GLB, giới hạn pool vùng, va chạm mặt đất, tọa độ âm, seed tái lập, mép vùng khớp, di chuyển/nhảy/tiếp đất, HUD/menu trong viewport, tạm dừng, dịch chuyển xa và tái sử dụng node, checkpoint, lưu/tải qua luồng chính, backup, file hỏng, schema sai, tọa độ NaN/không phải số.

**Gameplay test** đi từ New Game đến hết đoạn mẫu bằng chính các hàm game dùng (trigger, hội thoại, sát thương, rương, miếu, tiếng vọng, chuông, boss):

- Mọi nhiệm vụ chính/phụ/sự kiện chuyển bước và hoàn thành đúng; phần thưởng chỉ nhận một lần; rương không mở lại được.
- Stream đi stream lại không nhân đôi NPC; boss đã hạ không hồi sinh; rương đã mở giữ trạng thái.
- Khinh công bật nhảy; tường gió đóng trước câu đố; vào đấu trường bắt đầu trận; Trúc Tướng sang pha 2 dưới 50% máu.
- Lưu sau khi xong đoạn mẫu rồi tải lại; save v1 của bản nền migrate được và chơi tiếp được.
- Chiến đấu: một nhát chém chỉ trúng một lần; phản đòn đúng lúc làm địch choáng; né có khung bất tử; địch không bị đẩy xuống Khe Gió; navmesh bake từ collider đã stream.

**Giai đoạn 1 (lõi combat):** độc trừ máu theo thời gian không làm khựng và chặn Hồi xuân; độc đứng yên khi hội thoại khóa điều khiển; né rũ một lớp chảy máu; choáng đưa Lâm An vào trạng thái trúng đòn; buff cộng đúng chỉ số rồi hết hạn; đòn địch mang trạng thái chỉ dính khi trúng thật (đỡ: nửa tỉ lệ; né/phản: không); công thức phòng ngự, giáp địch và xuyên giáp; hút máu chỉ từ đòn trực tiếp; tốc độ ra đòn rút ngắn clip và khung gây sát thương cùng nhau; tuyệt kỹ Thủy và Băng Tiễn phát clip đúng tốc độ; mỗi phản ứng chỉ kích hoạt đúng tổ hợp, lan/nổ/nảy trúng địch khác một lần, không đệ quy; hết thế thì phá thế và mở cửa sổ kết liễu; kết liễu hạ gục địch thường, boss chỉ mất tối đa 12%; F ưu tiên kết liễu hơn tương tác khi giao chiến; né/phản hoàn hảo bật Tâm Nhãn, né muộn thì không, hết 1,5 s thời gian về 1,0, tạm dừng giữ nguyên bộ đếm; mua thuốc trừ Đồng, thiếu Đồng thì không đổi gì; Ngọc bội đúng khoảng chỉ số, dòng phụ không trùng, hiệu ứng bộ 2/3 món, túi đầy tự phân giải món thấp nhất, hồ sơ v1 migrate giữ nguyên tiền, bảo hiểm và kho kiếm.

| | |
|---|---|
| ![Icon trạng thái](screenshots/statuses.jpg) | ![Bảng Nhân vật](screenshots/character.jpg) |
| ![Quầy thuốc](screenshots/shop.jpg) | ![Ngọc bội](screenshots/talismans.jpg) |
| ![Điện Giật](screenshots/reaction_electrocharge.jpg) | ![Hỏa Lốc](screenshots/reaction_firestorm.jpg) |
| ![Thanh thế](screenshots/poise_bars.jpg) | ![Kết liễu](screenshots/finisher.jpg) |
| ![Tâm Nhãn](screenshots/focus.jpg) | ![Ông Lang Vân](screenshots/merchant.jpg) |

**Giai đoạn 2 (thời tiết, ngày–đêm, kiếm phụ):** đồng hồ quay vòng và đếm ngày, đêm ≈ 1/3 ngày, tạm dừng là dừng; thời tiết bốc theo trọng số vùng tái lập được từ seed, làng hiếm bão (< 4%), Ải luôn quang và thời tiết thung lũng chờ nguyên vẹn; tắt "Thời tiết động" thì trời quang; các mức chuyển mượt; điều kiện `time:`/`weather:` cả phủ định; save v4 lưu/tải giờ, ngày, thời tiết, RNG; save v1/v2/v3 migrate lên v4; nghỉ ở miếu tới sáng/tối; khí quyển trộn vùng × giờ × thời tiết đúng và ngừng ghi khi ổn định; mưa theo thời tiết × preset, không mưa trong nhà/Ải; gió bão đổi hạt bay; đèn đêm theo preset và chỉ sáng ban đêm; sét theo khoảng thời gian, sét đánh trúng địch và Lâm An trong vòng, không đánh trong làng hay khi hội thoại; lớp tiếng mưa/bão/dế theo trời; mưa Lôi ×1,2 / Hỏa ×0,8 cả hai phía; mưa làm Ướt ngoài trời, không làm Ướt trong Ải; sương ×0,6, đêm ×0,8, sàn ×0,45 tầm phát hiện; hạ địch ban đêm +25%; đổi kiếm phụ đổi hệ, nguyên tố, chỉ số, hồi 2,5 s, đòn đầu +30% và chắc chắn gây trạng thái (Điện Giật trên địch Ướt), không đổi khi đang né hay hội thoại, kiếm phụ còn sau khi lưu/tải.

| | |
|---|---|
| ![Làng chiều tà](screenshots/w_village_dusk.jpg) | ![Làng ban đêm](screenshots/w_village_night.jpg) |
| ![Mưa ở làng](screenshots/w_village_rain.jpg) | ![Sương ở Trúc Hải](screenshots/w_gorge_fog.jpg) |
| ![Bão có chớp](screenshots/w_bamboo_storm_flash.jpg) | ![Sét sắp đánh](screenshots/w_bamboo_storm_warn.jpg) |
| ![Bão đêm](screenshots/w_bamboo_storm_night.jpg) | ![Đèn lồng ban đêm](screenshots/w_village_night_lights.jpg) |

**Giai đoạn 3 (Kiếm Quyết, giao diện, quái mới, Web):** cầm kiếm không còn dạy hệ; mỗi hệ chỉ mở bằng nhiệm vụ của nó, đủ 6 hệ sau 5 nhiệm vụ mà không phải gắn lại phím; gắn hệ khác nhau cho E/Q/X và lưu/tải giữ nguyên; save cũ tự suy ra bộ gắn từ kiếm; trùng hệ với kiếm +15%; Địa Liệt Trảm trúng mỗi địch một lần trên cả hàng gai; khiên đá giảm sát thương nhận; 3 phản ứng Thổ; 7 quái mới với hành vi riêng (monster test); thanh máu boss không chồng lên khối HUD nào kể cả khi chữ trên viên thuốc dài; vùng dựng theo lát giống hệt từng bit.

| | |
|---|---|
| ![Kiếm Quyết](screenshots/kiem_quyet.jpg) | ![Vòng chọn hệ](screenshots/style_wheel.jpg) |
| ![Địa Liệt Trảm](screenshots/earth_fissure.jpg) | ![Sơn Băng Địa Liệt](screenshots/earth_quake.jpg) |
| ![Bảy quái mới](screenshots/bestiary.jpg) | ![Thanh máu boss](screenshots/boss_slam.jpg) |

## Kiểm tra hình ảnh — đã chạy (renderer phần mềm)

`tests/render_preview.gd` chụp các cảnh thật trong game (1920 × 1080, giao diện cơ sở 1280 × 720): bến sông, làng, hội thoại, giao tranh, Trúc Hải, Khe Gió, đấu trường, boss, bản đồ, nhật ký, túi đồ, thiết lập, ghi công, Kỳ Ngộ, kho kiếm, nhiệm vụ ngày, cảnh giới, Ải Vô Tận và bảng phúc lành. Cảnh "moves" tua từng đòn tới giữa khung gây sát thương (lấy từ `data/anim_timings.json`) và chụp nhìn ngang; một ảnh riêng chạy đòn thật ở tốc độ chậm để kiểm tra vệt kiếm. Đã kiểm tra bằng mắt: vật liệu toon, bóng, viền, vũ khí gắn tay, tư thế đòn khớp khung sát thương, chữ tiếng Việt đủ dấu, UI nằm trong khung hình.

| | |
|---|---|
| ![Màn hình chính](screenshots/title.jpg) | ![Bến sông](screenshots/dock.jpg) |
| ![Hội thoại](screenshots/dialogue.jpg) | ![Giao tranh](screenshots/combat_swing.jpg) |
| ![Trúc Hải](screenshots/bamboo.jpg) | ![Khe Gió](screenshots/gorge.jpg) |
| ![Trúc Tướng](screenshots/boss_slam.jpg) | ![Bản đồ](screenshots/map.jpg) |
| ![Nhật ký](screenshots/journal.jpg) | ![Túi đồ](screenshots/inventory.jpg) |
| ![Kỳ Ngộ](screenshots/gacha.jpg) | ![Kho kiếm & trang phục](screenshots/armory.jpg) |
| ![Ải Vô Tận](screenshots/trial_wave.jpg) | ![Chọn phúc lành](screenshots/trial_pick.jpg) |
| ![Nhiệm vụ ngày](screenshots/daily.jpg) | ![Cảnh giới thế giới](screenshots/tier.jpg) |

![Mười đòn của Lâm An ở giữa khung gây sát thương: chuỗi 3 đòn, trọng kích, Phong Trảm, Toàn Phong, phản đòn, né, lướt chém, tuyệt kỹ](screenshots/moves.jpg)

## Bản Web — đã build, đã chạy trong Chromium, đã deploy preview

- `tools/run.sh web` (cũng là lệnh build của Vercel qua `vercel.json`) tạo `build/web` **55 MB** trước nén: `index.wasm` 39,5 MB, `index.pck` 16,9 MB (thêm 7 model quái, 9 âm thanh, navmesh dựng sẵn 37 KB), `index.js` 0,3 MB. Bản không luồng nên không cần header COOP/COEP.
- `tools/run.sh websmoke`: Playwright + Chromium (SwiftShader) mở bản build, tới màn hình chính sau ~8 s (gồm biên dịch trước shader), vào chơi và đi bộ; **PASS**, không có `pageerror` hay `SCRIPT ERROR`.
- Chi phí stream đo **trong trình duyệt** (`VK_QUERY='?vkbench' node tools/web_smoke.cjs`, WebAssembly, 25/10): tính trọn một vùng 26–38 ms (một khung bị khựng nếu làm một lần); chia lát: 6–8 lát, lát lâu nhất 4,5–5,6 ms; navmesh vùng nhỏ nhất bake trực tiếp 24–36 ms, nạp bản dựng sẵn 1,5–1,8 ms (4 lần chạy, máy không chạy việc khác; khi CPU bị chiếm, số tăng gấp rưỡi tới gấp đôi). Native cùng máy: một vùng 19,4 ms (trước tối ưu `WorldLayout` ~36 ms), lát lâu nhất 4,5 ms. FPS trong Chromium headless (~1 khung/s, dựng hình phần mềm) không có ý nghĩa và không dùng để kết luận.
- Vercel (project `game-openworld`) tự build mỗi lần push nhánh; các bản preview của nhánh đều ở trạng thái READY. Preview đang bật Vercel Authentication nên chỉ tài khoản trong team xem được.

## Hiệu năng — chưa đo được trên GPU thật

Môi trường không có GPU; llvmpipe chỉ đạt 3–5 FPS và **không phản ánh** mục tiêu 1080p Medium 60 FPS. Không suy diễn hiệu năng từ số này hay từ test headless.

Đo trên máy Windows có GPU:

```powershell
./tools/run.ps1 -Mode preview      # 1920x1080, chất lượng theo Thiết lập (mặc định Trung bình)
```

Script in `PROFILE setup` (độ phân giải, GPU, chất lượng) rồi ba dòng `PROFILE village`, `PROFILE region_transition`, `PROFILE boss_fight` gồm FPS trung bình, p50/p95 thời gian khung hình, số draw call lớn nhất, bộ nhớ tĩnh và video. Ghi kết quả cùng CPU/GPU/RAM vào bảng dưới.

| Máy | Cảnh | FPS TB | p95 ms | Draw call | RAM tĩnh | VRAM |
|---|---|---:|---:|---:|---:|---:|
| _GPU thật — chưa đo_ | | | | | | |
| Xeon 4 nhân, llvmpipe, 1280 × 720 (chỉ để xác nhận script chạy) | Làng | 3,2 | 391 | 778 | 106 MB | 51 MB |
| như trên | Chuyển vùng | 3,1 | 361 | 1 242 | 106 MB | 52 MB |
| như trên | Trận boss | 3,3 | 335 | 480 | 106 MB | 50 MB |

Bộ nhớ và số draw call không phụ thuộc GPU nên đã dùng được làm ngân sách ban đầu: ~106 MB RAM tĩnh, ~51 MB VRAM, tối đa ~1 250 draw call khi chuyển vùng (cao nhất ở bến sông/chuyển vùng do nhiều đạo cụ riêng lẻ). Nếu đo trên GPU thật thấy nghẽn ở CPU/driver, ưu tiên gộp đạo cụ tĩnh cùng vật liệu thành MultiMesh.

Các biện pháp đã có: pool vùng cố định 25 node, tính mesh trên worker thread (bản Web: chia lát ≤ 5 ms mỗi khung), navmesh dựng sẵn, biên dịch trước shader, nội suy mô hình Lâm An và camera giữa hai bước vật lý, tự hạ độ phân giải 3D trên Web khi chậm, MultiMesh cho cây/cỏ/đá, khoảng hiển thị theo chất lượng (cỏ 26/46/60 m, cây chi tiết 48/72/96 m, xa hơn dùng bóng cây ít đa giác), giới hạn bóng đổ 0/55/90 m, MSAA 0/2×/4×, NPC/địch/vật tương tác chỉ được tạo trong bán kính 85 m và hủy khi xa hơn 115 m, navmesh chỉ bake ở khu giao tranh.

## Bản Windows — đã build, chưa chạy thử trên Windows

`--export-release "Windows Desktop"` tạo `VanKhe.exe` (~104 MB) và `VanKhe.pck` (~11 MB). Đã kiểm tra: pack chứa dữ liệu JSON, model đã import, âm thanh, font và văn bản giấy phép; chạy pack đó bằng Godot Linux cùng phiên bản (headless) vào được màn hình chính không lỗi. **Chưa** chạy `VanKhe.exe` trên Windows thật (môi trường không có Windows).

## Chưa kiểm tra

- Người chơi thật chơi thử (cảm giác điều khiển, độ khó, thời lượng thực tế).
- FPS/frame time trên GPU thật; 720p/1080p trên màn hình thật (đã kiểm tra bố cục UI ở 1280 × 720 trong ảnh chụp).
- Âm thanh nghe thực tế: môi trường không có loa; đã kiểm tra bằng phân tích độ lớn/phổ, cần người nghe duyệt.
- Gamepad, macOS.
