# Kết quả kiểm tra — 18/10/2026

Phân biệt rõ: **đã chạy** (có log/ảnh) và **chưa chạy được** trong môi trường phát triển.

## Môi trường đã dùng

- Linux container, Intel Xeon 2,8 GHz 4 nhân, 15 GB RAM, **không có GPU**. Render bằng Mesa llvmpipe (OpenGL 4.5, phần mềm) qua Xvfb.
- Godot `4.7.2.stable.official.ed1daf0bf` (bản Linux chính thức, cùng commit với bản Windows ghim trong `dependencies.json`), renderer GL Compatibility.
- Blender 5.2.2 LTS (chạy nền). Python 3 + Pillow, FluidSynth, ffmpeg cho công cụ nội dung.

## Kiểm thử tự động — đã chạy

| Bộ test | Lệnh | Kết quả |
|---|---|---|
| Import asset | `godot --headless --path . --editor --import` | Thành công |
| Smoke test (bản nền + thực vật, vùng cấm, preset) | `tests/smoke_test.gd` | **35/35 PASS** |
| Gameplay test (chơi trọn đoạn mẫu) | `tests/gameplay_test.gd` | **48/48 PASS** |
| Combat test (15 thức của 5 hệ, trạng thái, nộ khí) | `tests/combat_test.gd` | **53/53 PASS** |
| Progression test (save v3, hồ sơ, gacha, nhiệm vụ ngày, Ải Vô Tận, cảnh giới) | `tests/progression_test.gd` | **49/49 PASS** |

Tổng **185/185 PASS**. `./tools/run.ps1 -Mode test` (Windows) và `tools/run.sh test` (Linux) chạy import rồi cả bốn bộ. CI GitHub Actions chạy trên `windows-latest`.

**Combat test:** mỗi thức E/Q/X của 5 hệ khởi động, gây sát thương và gây đúng trạng thái; thiêu đốt gây sát thương theo thời gian không làm khựng; lạnh cóng làm chậm, 3 lớp thành đóng băng, boss không bị đóng băng; mục tiêu ướt chỉ nhận thêm sát thương sấm; tuyệt kỹ bị từ chối khi nộ khí chưa đầy và tiêu hết khi dùng; Phong Trảm vẫn bằng công lực × 1,6 như bản trước.

**Progression test:** 200.000 lượt quay có tỉ lệ Cực phẩm 2,44% so với tỉ lệ tổng hợp công khai 2,43%; không chuỗi nào vượt lượt bảo hiểm 70; mỗi 10 lượt có Hiếm; trượt 50/50 thì lần sau chắc chắn ra kiếm nổi bật; thiếu Ngọc bị từ chối không đổi gì; bảo hiểm và kho kiếm còn nguyên sau khi tải lại hồ sơ; trang phục trùng đổi thành Mảnh; chỉ số phụ không trùng, đúng khoảng, đúng số dòng theo độ hiếm; nhiệm vụ ngày làm mới theo ngày, thưởng nhận một lần, điểm danh đứt chuỗi khi bỏ ngày. Cảnh thật: cổng Ải đưa vào đấu trường, đợt 1 có 3 địch, không lưu được trong lượt, xong đợt thì dừng ở bảng phúc lành mà Esc không đóng được, Kiếm Phong tăng đúng 15% đòn thường, Trúc Tướng đợt 5 có máu theo hệ số đợt, gục ngã thì về cổng, nhận thưởng và không ghi cờ cốt truyện; cảnh giới 1 Trúc Tướng có 1,7 lần máu, hạ xong ghi `tier_dead:1:` và mở cảnh giới 2; tinh anh có nhãn và không sửa dữ liệu dùng chung.

**Smoke test:** nạp GLB, giới hạn pool vùng, va chạm mặt đất, tọa độ âm, seed tái lập, mép vùng khớp, di chuyển/nhảy/tiếp đất, HUD/menu trong viewport, tạm dừng, dịch chuyển xa và tái sử dụng node, checkpoint, lưu/tải qua luồng chính, backup, file hỏng, schema sai, tọa độ NaN/không phải số.

**Gameplay test** đi từ New Game đến hết đoạn mẫu bằng chính các hàm game dùng (trigger, hội thoại, sát thương, rương, miếu, tiếng vọng, chuông, boss):

- Mọi nhiệm vụ chính/phụ/sự kiện chuyển bước và hoàn thành đúng; phần thưởng chỉ nhận một lần; rương không mở lại được.
- Stream đi stream lại không nhân đôi NPC; boss đã hạ không hồi sinh; rương đã mở giữ trạng thái.
- Khinh công bật nhảy; tường gió đóng trước câu đố; vào đấu trường bắt đầu trận; Trúc Tướng sang pha 2 dưới 50% máu.
- Lưu sau khi xong đoạn mẫu rồi tải lại; save v1 của bản nền migrate được và chơi tiếp được.
- Chiến đấu: một nhát chém chỉ trúng một lần; phản đòn đúng lúc làm địch choáng; né có khung bất tử; địch không bị đẩy xuống Khe Gió; navmesh bake từ collider đã stream.

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

- `tools/run.sh web` (cũng là lệnh build của Vercel qua `vercel.json`) tạo `build/web` **51 MB** trước nén: `index.wasm` 39,5 MB, `index.pck` 12,7 MB, `index.js` 0,3 MB. Bản không luồng nên không cần header COOP/COEP.
- `tools/run.sh websmoke`: Playwright + Chromium (SwiftShader) mở bản build, tới màn hình chính sau ~5–7 s, vào chơi và đi bộ; **PASS**, không có `pageerror` hay `SCRIPT ERROR`. Cảnh báo duy nhất: navmesh làm tròn `agent_radius` (không ảnh hưởng).
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

Các biện pháp đã có: pool vùng cố định 25 node, tính mesh trên worker thread, MultiMesh cho cây/cỏ/đá, khoảng hiển thị theo chất lượng (cỏ 26/46/60 m, cây chi tiết 48/72/96 m, xa hơn dùng bóng cây ít đa giác), giới hạn bóng đổ 0/55/90 m, MSAA 0/2×/4×, NPC/địch/vật tương tác chỉ được tạo trong bán kính 85 m và hủy khi xa hơn 115 m, navmesh chỉ bake ở khu giao tranh.

## Bản Windows — đã build, chưa chạy thử trên Windows

`--export-release "Windows Desktop"` tạo `VanKhe.exe` (~104 MB) và `VanKhe.pck` (~11 MB). Đã kiểm tra: pack chứa dữ liệu JSON, model đã import, âm thanh, font và văn bản giấy phép; chạy pack đó bằng Godot Linux cùng phiên bản (headless) vào được màn hình chính không lỗi. **Chưa** chạy `VanKhe.exe` trên Windows thật (môi trường không có Windows).

## Chưa kiểm tra

- Người chơi thật chơi thử (cảm giác điều khiển, độ khó, thời lượng thực tế).
- FPS/frame time trên GPU thật; 720p/1080p trên màn hình thật (đã kiểm tra bố cục UI ở 1280 × 720 trong ảnh chụp).
- Âm thanh nghe thực tế: môi trường không có loa; đã kiểm tra bằng phân tích độ lớn/phổ, cần người nghe duyệt.
- Gamepad, macOS.
