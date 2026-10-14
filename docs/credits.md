# Ghi công và giấy phép

Vân Khê — Dư Âm Gió. Thiết kế và sở hữu: Nguyễn Thành Long. Mã nguồn, model, animation, nhạc và hiệu ứng âm thanh tự tạo cho dự án; chủ repo chưa chọn giấy phép phân phối cho các phần này.

## Thành phần bên thứ ba có trong bản game

| Thành phần | Dùng cho | Giấy phép | Ghi chú |
|---|---|---|---|
| [Godot Engine 4.7.2](https://godotengine.org) | Engine, runtime xuất bản | MIT — © Godot Engine contributors, Juan Linietsky, Ariel Manzur | Kèm thông báo bản quyền khi phát hành; xem [hướng dẫn](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html). Thông báo của các thư viện Godot tích hợp nằm trong `Engine.get_license_info()` / `Engine.get_copyright_info()`. |
| [Be Vietnam Pro](https://fonts.google.com/specimen/Be+Vietnam+Pro) | Chữ giao diện | SIL OFL 1.1 | `assets/fonts/OFL-BeVietnamPro.txt` |
| [Lora](https://fonts.google.com/specimen/Lora) | Chữ tiêu đề | SIL OFL 1.1 | `assets/fonts/OFL-Lora.txt` |
| [Kenney](https://kenney.nl) — Impact Sounds, RPG Audio, Interface Sounds | Bước chân, va chạm, rương, đồng xu, UI | CC0 1.0 | Không bắt buộc ghi công; danh sách file trong `docs/assets.md` |
| [FluidR3_GM](https://github.com/FluidSynth/fluidsynth/wiki/SoundFont) (Frank Wen) | Âm sắc nhạc cụ khi render nhạc | MIT | Chỉ dùng lúc tạo file OGG; soundfont không nằm trong game |

## Công cụ dùng để tạo nội dung (không phân phối kèm game)

| Công cụ | Vai trò |
|---|---|
| Blender 5.2.2 | Dựng model, rig, animation bằng script chạy nền (`tools/blender/`) |
| FluidSynth 2.3, mido | Render MIDI soạn bằng code thành nhạc (`tools/audio/compose_music.py`) |
| numpy, scipy, ffmpeg (libvorbis) | Tổng hợp hiệu ứng, âm nền, mã hóa OGG (`tools/audio/build_sfx.py`) |
| Pillow | Ghép ảnh xem trước model |
