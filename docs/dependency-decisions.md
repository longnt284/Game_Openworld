# Lựa chọn repo

Đánh giá ngày 13/10/2026, trước khi viết gameplay. Chỉ một engine chạy game để tránh chồng hệ render, vật lý, build và ngôn ngữ.

| Repo được đề xuất | Quyết định | Cách dùng / lý do |
|---|---|---|
| [Godot](https://github.com/godotengine/godot) | **Dùng** | Engine 3D, vật lý, scene, editor, import GLB; tải release 4.7.2-stable có SHA-256 thay vì clone/build toàn bộ mã C++ |
| [Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) | **Tham khảo tùy chọn** | Repo quy trình phát triển, tham khảo kiểu dữ liệu GDScript, async asset và kiểm tra chất lượng; clone vào `.cache/studio-reference` tại commit cố định |
| [PixiJS](https://github.com/pixijs/pixijs) | Không thêm | Thư viện render 2D; HUD hiện dùng Control của Godot |
| [Babylon.js](https://github.com/BabylonJS/Babylon.js) | Không thêm | Engine 3D web thay thế; đánh giá lại nếu yêu cầu browser-first |
| [libGDX](https://github.com/libgdx/libgdx) | Không thêm | Framework Java thay thế, không cần thêm JVM/toolchain cho base Godot |
| [Caveman](https://github.com/JuliusBrussee/caveman) | Không thêm | Công cụ/skill cho coding agent; không bổ sung tính năng chạy game |

`dependencies.json` ghi nguồn, vai trò và phiên bản. `tools/setup.ps1 -WithStudioReference` lấy đúng hai thành phần đã chọn. Bản clone tham khảo và engine được gitignore; clone mới vẫn tự dựng được qua script. Không sao chép hoặc kích hoạt hooks, agent, proxy hay cấu hình tài khoản từ repo tham khảo.

Godot phát hành theo MIT. Repo Game Studios tham khảo ở commit `be8993bbc5a1f016bc770b2846ce06272d284526`, MIT, copyright 2026 Donchitos. Không có mã runtime của Game Studios được vendor vào game. Mã nguồn và tài nguyên mới của dự án chưa tự ý gán giấy phép phân phối; chủ repo quyết định giấy phép cho game.

Khi phân phối bản game có Godot, kèm thông báo bản quyền engine và các thư viện tích hợp theo [hướng dẫn license Godot](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html). Cài đặt dev hiện dùng binary release nguyên gốc.
