# Kết quả kiểm tra — 14/10/2026

Phân biệt rõ: **đã chạy** (có log/ảnh) và **chưa chạy được** trong môi trường phát triển.

## Môi trường đã dùng

- Linux container, Intel Xeon 2,8 GHz 4 nhân, 15 GB RAM, **không có GPU**. Render bằng Mesa llvmpipe (OpenGL 4.5, phần mềm) qua Xvfb.
- Godot `4.7.2.stable.official.ed1daf0bf` (bản Linux chính thức, cùng commit với bản Windows ghim trong `dependencies.json`), renderer GL Compatibility.
- Blender 5.2.2 LTS (chạy nền). Python 3 + Pillow, FluidSynth, ffmpeg cho công cụ nội dung.

## Kiểm thử tự động — đã chạy

| Bộ test | Lệnh | Kết quả |
|---|---|---|
| Import asset | `godot --headless --path . --editor --import` | Thành công |
| Smoke test (bản nền, giữ nguyên độ bao phủ) | `tests/smoke_test.gd` | **29/29 PASS** |
| Gameplay test (chơi trọn đoạn mẫu) | `tests/gameplay_test.gd` | **44/44 PASS** |

`./tools/run.ps1 -Mode test` (Windows) và `tools/run.sh test` chạy cả ba bước. CI GitHub Actions chạy trên `windows-latest`.

**Smoke test:** nạp GLB, giới hạn pool vùng, va chạm mặt đất, tọa độ âm, seed tái lập, mép vùng khớp, di chuyển/nhảy/tiếp đất, HUD/menu trong viewport, tạm dừng, dịch chuyển xa và tái sử dụng node, checkpoint, lưu/tải qua luồng chính, backup, file hỏng, schema sai, tọa độ NaN/không phải số.

**Gameplay test** đi từ New Game đến hết đoạn mẫu bằng chính các hàm game dùng (trigger, hội thoại, sát thương, rương, miếu, tiếng vọng, chuông, boss):

- Mọi nhiệm vụ chính/phụ/sự kiện chuyển bước và hoàn thành đúng; phần thưởng chỉ nhận một lần; rương không mở lại được.
- Stream đi stream lại không nhân đôi NPC; boss đã hạ không hồi sinh; rương đã mở giữ trạng thái.
- Khinh công bật nhảy; tường gió đóng trước câu đố; vào đấu trường bắt đầu trận; Trúc Tướng sang pha 2 dưới 50% máu.
- Lưu sau khi xong đoạn mẫu rồi tải lại; save v1 của bản nền migrate được và chơi tiếp được.
- Chiến đấu: một nhát chém chỉ trúng một lần; phản đòn đúng lúc làm địch choáng; né có khung bất tử; địch không bị đẩy xuống Khe Gió; navmesh bake từ collider đã stream.

## Kiểm tra hình ảnh — đã chạy (renderer phần mềm)

`tests/render_preview.gd` chụp các cảnh thật trong game (ảnh trong `docs/screenshots/`): bến sông, làng, hội thoại, giao tranh, từng đòn đánh nhìn ngang, Trúc Hải, Khe Gió, đấu trường, boss, bản đồ, nhật ký, túi đồ, thiết lập, ghi công, màn hình chính. Đã kiểm tra bằng mắt: vật liệu toon, bóng, viền, vũ khí gắn tay, tư thế đòn đánh khớp khung gây sát thương, chữ tiếng Việt đủ dấu, UI nằm trong khung 1280 × 720.

## Hiệu năng — chưa đo được trên GPU thật

Môi trường không có GPU; llvmpipe chỉ đạt 3–5 FPS và **không phản ánh** mục tiêu 1080p Medium 60 FPS. Không suy diễn hiệu năng từ số này hay từ test headless.

Đo trên máy Windows có GPU:

```powershell
./tools/run.ps1 -Mode preview      # 1920x1080, chất lượng theo Thiết lập (mặc định Trung bình)
```

Script in `PROFILE setup` (độ phân giải, GPU, chất lượng) rồi ba dòng `PROFILE village`, `PROFILE region_transition`, `PROFILE boss_fight` gồm FPS trung bình, p50/p95 thời gian khung hình, số draw call lớn nhất, bộ nhớ tĩnh và video. Ghi kết quả cùng CPU/GPU/RAM vào bảng dưới.

| Máy | Cảnh | FPS TB | p95 ms | Draw call | RAM tĩnh | VRAM |
|---|---|---:|---:|---:|---:|---:|
| _(chưa đo)_ | | | | | | |

Các biện pháp đã có: pool vùng cố định 25 node, tính mesh trên worker thread, MultiMesh cho cây/cỏ/đá, khoảng hiển thị theo chất lượng (cỏ 26/46/60 m, cây chi tiết 48/72/96 m, xa hơn dùng bóng cây ít đa giác), giới hạn bóng đổ 0/55/90 m, MSAA 0/2×/4×, NPC/địch/vật tương tác chỉ được tạo trong bán kính 85 m và hủy khi xa hơn 115 m, navmesh chỉ bake ở khu giao tranh.

## Bản Windows — đã build, chưa chạy thử trên Windows

`--export-release "Windows Desktop"` tạo `VanKhe.exe` (~104 MB) và `VanKhe.pck` (~11 MB). Đã kiểm tra: pack chứa dữ liệu JSON, model đã import, âm thanh, font và văn bản giấy phép; chạy pack đó bằng Godot Linux cùng phiên bản (headless) vào được màn hình chính không lỗi. **Chưa** chạy `VanKhe.exe` trên Windows thật (môi trường không có Windows).

## Chưa kiểm tra

- Người chơi thật chơi thử (cảm giác điều khiển, độ khó, thời lượng thực tế).
- FPS/frame time trên GPU thật; 720p/1080p trên màn hình thật (đã kiểm tra bố cục UI ở 1280 × 720 trong ảnh chụp).
- Âm thanh nghe thực tế: môi trường không có loa; đã kiểm tra bằng phân tích độ lớn/phổ, cần người nghe duyệt.
- Gamepad, macOS.
