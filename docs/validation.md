# Kết quả kiểm tra — 13/10/2026

## Môi trường

- Windows, Godot `4.7.2.stable.official.ed1daf0bf`.
- Blender `5.2.2 LTS`: tạo lại cả ba `.blend` và `.glb` thành công.
- Render GL Compatibility, OpenGL 3.3, NVIDIA GeForce RTX 3050 Ti Laptop GPU, driver 581.57, viewport 1280 × 720.

## Kiểm thử tự động

`tools/run.ps1 -Mode test`: import thành công, **27 kiểm tra PASS, 0 thất bại**. Cùng `smoke_test.gd` cũng chạy thành công với renderer thật, bao gồm đường tải GLB bất đồng bộ.

Bao phủ: khởi tạo GLB, giới hạn vùng, va chạm mặt đất, tọa độ âm, seed, mép địa hình, di chuyển/nhảy/tiếp đất, HUD/menu trong viewport, pause, dịch chuyển xa/tái sử dụng node, checkpoint, lưu/tải lại seed và vị trí, dựng lại terrain sau load, round-trip JSON, bản backup, version và dữ liệu tọa độ sai.

Chế độ headless dùng tải asset đồng bộ vì bước instantiate mesh từ tài nguyên tải nền từng phát sinh lỗi RID với dummy renderer trên máy thử. Game có render vẫn dùng `ResourceLoader.load_threaded_request`; test GPU đã kiểm tra đường này. CI chạy import và bộ test headless từ checkout mới, không cần Blender.

## Kiểm tra render và hiệu năng

`tests/render_preview.gd` chụp viewport sau warm-up, sau đó điều khiển nhân vật chạy tiến trong 600 frame có render:

| Phép đo | Kết quả |
|---|---:|
| FPS tại ảnh preview | 137 |
| Draw calls tại ảnh preview | 247 |
| p95 thời gian giữa các frame | 8,097 ms |
| Thời gian dựng một vùng lớn nhất ghi nhận | 2,147 ms |
| Khoảng cách nhân vật đi được | 36,17 m |
| Số vùng đang giữ cuối phép đo | 25 |

Đây là phép đo ngắn trên một máy, không phải cam kết FPS cho mọi GPU, cấu hình, quy mô map hoặc asset về sau. Chưa kiểm thử multiplayer, mobile, macOS/Linux hay bản export độc lập. Xem ảnh [preview.png](preview.png).

Để chạy lại phép đo, dùng Godot có render:

```powershell
./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/render_preview.gd
```

Ảnh mới ghi vào `.cache/preview.png`, thống kê in ra console. Không dùng `--headless` cho phép đo render.
