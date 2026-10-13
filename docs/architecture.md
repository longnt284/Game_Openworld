# Kiến trúc bản nền

Engine được cố định trong `dependencies.json`. Dự án dùng Godot + GDScript, GL Compatibility và đầu vào bàn phím/chuột; mục tiêu ban đầu là desktop Windows. Blender chỉ cần khi sửa hoặc tạo lại model. File GLB đã nằm trong repo nên người chơi và CI không cần Blender.

## Các phần chính

| Thành phần | Trách nhiệm |
|---|---|
| `main.gd` | Khởi tạo, ánh sáng, checkpoint, pause, kết nối lưu/tải |
| `game_settings.gd` / `default_settings.tres` | Seed, tốc độ, kích thước và số vùng địa hình |
| `player_controller.gd` | CharacterBody3D, chạy/nhảy, SpringArm camera và trạng thái di chuyển |
| `asset_library.gd` | Tải GLB bằng ResourceLoader trên luồng nền, kiểm tra thất bại |
| `world_manager.gd` | Lịch tải vùng theo khoảng cách, giới hạn pool và tái sử dụng node |
| `world_chunk.gd` | Mesh địa hình, collider, MultiMesh cây/đá, LOD cây theo khoảng cách |
| `save_store.gd` | JSON có version, kiểm tra đầu vào, ghi tạm và phục hồi từ backup |
| `game_hud.gd` | Thông tin khám phá, điều khiển và menu tạm dừng |

## Quy ước thế giới

- Một đơn vị là một mét, Godot dùng Y hướng lên. Blender export tự chuyển Z-up sang Y-up.
- Vùng mặc định 32 × 32 m, lưới 16 × 16 ô; 25 vùng quanh người chơi.
- Mọi đỉnh lấy độ cao từ tọa độ thế giới nên mép vùng khớp nhau. Seed tái tạo độ cao và vị trí cây trong phiên bản engine đã cố định.
- Tạo sẵn pool 25 node vùng. Mỗi frame cấu hình tối đa một vùng; hàng chờ được cập nhật khi người chơi đổi vùng. Đây là sinh mesh theo ngân sách trên main thread, không phải terrain worker thread.
- Người chơi dừng vật lý khi vùng dưới chân chưa sẵn sàng, tránh rơi khi dịch chuyển xa. Các vùng xa được trả lại pool.
- Cây/đá chia sẻ mesh bằng MultiMesh. Cây ngoài khoảng cách cấu hình dùng silhouette ít đa giác; quyết định LOD theo vị trí node vùng. Thân cây và mặt đất có va chạm; đá mẫu chỉ trang trí.
- Khi chơi có hình ảnh, GLB được tải bất đồng bộ; vật liệu và mesh chia sẻ cho mọi vùng. Trong headless, tải trên main thread để tránh lỗi RID khi dummy renderer của Godot khởi tạo mesh từ tài nguyên tải nền. Cả hai đường chạy đều được kiểm tra.

## Lưu game

F5 ghi `user://world_save.json` với version, seed, vị trí, checkpoint và trạng thái trạm. F9 tải và tái lập thế giới. Ghi qua `.tmp`, giữ bản trước trong `.bak`; nếu bản chính lỗi, đọc bản backup hợp lệ. Test dùng tên file riêng, không ghi vào save người chơi. Thay đổi schema hoặc thuật toán terrain về sau cần migration rõ ràng.

## Mở rộng tiếp

1. Thay capsule bằng nhân vật rig/animation trong scene riêng.
2. Đưa biome, vật phẩm và nhiệm vụ vào Resource; tránh phụ thuộc trực tiếp giữa UI và luật game.
3. Nếu đo được giật khi sinh vùng, chuyển tính vertex sang WorkerThreadPool; cập nhật scene/physics ở main thread.
4. Thêm origin shifting trước khi mở thế giới vượt hàng chục km; tọa độ lưu hiện được giới hạn ±100.000 m để loại dữ liệu lỗi, không phải cam kết độ chính xác tại khoảng cách đó.
5. Thêm input gamepad, rebinding, accessibility và export preset cho nền tảng thực sự cần.

Bản nền chưa có multiplayer, combat, inventory, navigation AI, hệ thống nhiệm vụ hoàn chỉnh hoặc xuất bản thương mại. Chu kỳ ánh sáng hiện là thay đổi góc/cường độ mặt trời đơn giản, chưa mô phỏng đầy đủ trời đêm.
