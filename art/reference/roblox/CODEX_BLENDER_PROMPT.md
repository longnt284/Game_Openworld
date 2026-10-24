# Prompt cho Codex — Nâng cấp Vân Khê theo phong cách Roblox bằng Blender MCP

## Cách sử dụng

Gửi toàn bộ prompt này cho Codex tại thư mục gốc của repo:

https://github.com/longnt284/Game_Openworld.git

Đính kèm hoặc đặt năm ảnh trong thư mục `references/` để Codex có thể đọc:

1. `references/01_lam_an_character.png`
2. `references/02_van_khe_village.png`
3. `references/03_truc_hai_forest.png`
4. `references/04_khe_gio_traversal.png`
5. `references/05_truc_tuong_boss.png`

---

## PROMPT

Bạn là Technical Art Director kiêm Blender/Godot Developer. Hãy nâng cấp đồ họa repo **Game_Openworld — Vân Khê: Dư Âm Gió** dựa trên năm ảnh tham chiếu được cung cấp và thực hiện trực tiếp qua **Blender MCP**.

### 1. Nguyên tắc làm việc

- Trước tiên, đọc `README.md`, `docs/game-design.md`, `docs/assets.md`, `docs/blender-pipeline.md`, `docs/progress.md`, cấu trúc `art/`, `assets/models/`, `tools/blender/`, shader và các scene Godot liên quan.
- Xác nhận đúng phiên bản Godot, Blender, cấu trúc asset, tên animation và đường dẫn runtime từ repo; không suy đoán khi có thể kiểm tra trong code.
- Dùng **một agent chính**. Không chạy agent team hoặc workflow khảo sát lớn. Chỉ dùng tối đa một subagent cho một vấn đề chuyên biệt nếu thật sự cần.
- Tận dụng generator, rig, animation và asset hiện có. Tránh viết lại gameplay hoặc hệ thống không liên quan đến nâng cấp hình ảnh.
- Nếu phát hiện xung đột có thể làm hỏng save, animation, collision hoặc gameplay, hỏi tôi trước khi thay đổi kiến trúc. Các lựa chọn kỹ thuật thông thường được tự quyết định và ghi lại.
- Mọi thay đổi phải có thể tái tạo bằng script, được lưu trong repo và không phụ thuộc thao tác Blender thủ công không được ghi nhận.

### 2. Mục tiêu hình ảnh

Chuyển game sang phong cách **blocky 3D hiện đại lấy cảm hứng từ game phiêu lưu Roblox**, nhưng sử dụng thiết kế nguyên bản của Vân Khê:

- Nhân vật có torso, tay và chân dạng khối với bevel vừa phải; tỷ lệ khoảng 5–6 đầu; silhouette dễ đọc từ camera góc nhìn thứ ba.
- Khuôn mặt anime tối giản, mắt hổ phách rõ, tóc tạo bằng các cụm mesh lớn.
- Kiến trúc, cây cối, vách núi và đạo cụ được dựng theo module low/mid-poly, màu tươi, hình khối rõ.
- Vật liệu dùng màu phẳng, roughness nhẹ, AO và highlight cạnh có kiểm soát; cel-shading 2–3 cấp sáng tối.
- Bảng màu chính: ngọc bích, xanh trúc, kem; điểm nhấn đỏ son và vàng.
- Giữ cảm giác võ hiệp Việt–Á Đông, không sao chép nhân vật, mesh, texture, logo hoặc asset độc quyền của Roblox hay game khác.
- Chất lượng hướng đến một game indie hoàn chỉnh: đẹp trong gameplay thực, không chỉ đẹp ở ảnh render cận cảnh.

### 3. Thứ tự ưu tiên của ảnh tham chiếu

- Ảnh là chuẩn cho **silhouette, màu sắc, mật độ chi tiết, vật liệu và bố cục**.
- Code và dữ liệu repo là chuẩn cho **kích thước gameplay, collision, vị trí, tên asset, rig, animation và chức năng**.
- Khi ảnh và gameplay mâu thuẫn, giữ gameplay rồi điều chỉnh hình ảnh cho phù hợp.

### 4. Prototype bắt buộc trước khi nâng toàn bộ

Chỉ làm hai hạng mục đầu tiên:

1. **Lâm An** hoàn chỉnh: model, rig, vật liệu, kiếm, animation tương thích.
2. **Một lát cắt làng Vân Khê** gồm một nhà nhỏ, một đoạn đường, giếng, quầy hàng, đèn lồng, một cụm tre và cây phong.

Tích hợp hai hạng mục vào một scene kiểm thử Godot với camera và ánh sáng gần gameplay thật. Chụp các góc:

- Lâm An: trước, sau, nghiêng và gameplay camera.
- Làng: cùng góc nhìn với `02_van_khe_village.png`, thêm một ảnh ban ngày và một ảnh ánh sáng chiều.

Trước khi mở rộng, báo cáo:

- Những điểm đã đạt và chưa đạt so với ảnh.
- Triangle count, material count, texture size, draw-call ước tính và FPS đo được.
- Các vấn đề về rig, clipping, collision, shader hoặc import.
- Danh sách điều chỉnh đề xuất cho vòng tiếp theo.

Sau khi prototype đạt tiêu chí, áp dụng hệ thống đã chốt cho các asset còn lại.

### 5. Yêu cầu cho Lâm An

Dùng `01_lam_an_character.png` làm chuẩn:

- Giữ tóc đen cột cao bằng dây đỏ, mắt hổ phách, áo võ phục xanh ngọc, lớp áo trong màu kem, khăn ngắn màu sáng, đai đỏ, quần tối, giày và bao tay nâu.
- Giữ kiếm thẳng cũ và bao kiếm ở hông trái.
- Áo ngoài chia thành các mảng mesh chắc chắn, hạn chế lớp vải mỏng dễ xuyên người.
- Tạo block avatar tùy biến, không dùng hình dạng starter avatar mặc định.
- Ưu tiên deform sạch tại vai, khuỷu, hông và đầu gối; kiểm tra clipping ở chạy, né, đỡ, xoay kiếm và khinh công.
- Tái sử dụng skeleton hiện có nếu phù hợp. Nếu cần sửa rig, giữ nguyên interface mà Godot đang gọi.
- Giữ đúng các tên animation được repo sử dụng, bao gồm tối thiểu: `idle`, `walk`, `run`, `jump`, `fall`, `land`, `dodge`, `block`, `parry`, `attack_1`, `attack_2`, `attack_3`, `heavy`, `skill_gust`, `skill_cyclone`, `air_leap`, `glide`, `hit`, `death`, `interact`.
- Nếu retarget, kiểm tra thời điểm hitbox theo `data/anim_timings.json`; không làm lệch nhịp chiến đấu.

Ngân sách tham chiếu cho LOD0: khoảng 10.000–18.000 tris, tối đa 4 material slots và một texture atlas 2K. Tạo LOD1 khoảng 50–60% và LOD2 khoảng 20–30% nếu pipeline hiện tại hỗ trợ ổn định.

### 6. Trúc Tướng và NPC

Dùng `05_truc_tuong_boss.png` làm chuẩn cho Trúc Tướng:

- Cao khoảng 1,55–1,65 lần Lâm An.
- Giáp phiến tre xanh đậm, viền vàng tiết chế, nón lá giáp xanh, mặt nạ sáng có ấn cyan, đai đỏ và trường đao cán xanh.
- Tách giáp thành module lớn, silhouette rõ; không biến thành robot hoặc golem khổng lồ.
- Giữ toàn bộ animation và telegraph đang được gameplay sử dụng.

NPC thường dùng cùng base rig, nhưng thay đổi đầu, tóc, quần áo, phụ kiện và palette. Không tạo mỗi NPC bằng một rig hoàn toàn khác nếu không cần thiết.

### 7. Môi trường và modular kit

Dựa trên các ảnh 02–05, tạo asset library theo module:

- **Làng:** wall bay, corner, cửa, cửa sổ, cột, xà, móng, bậc, mái thẳng, mái góc, nóc, cổng làng, giếng, quầy hàng, ghế, bàn, thùng, giỏ, đèn lồng, biển, lò rèn.
- **Trúc Hải:** 3 thân tre, 4 cụm lá, 4–6 cụm tre hoàn chỉnh, đá rêu, hoa, cầu gỗ, đèn đá, vọng gác và memory stone.
- **Khe Gió:** cliff module thẳng, góc trong, góc ngoài, đỉnh cỏ, đá rời, cột chỉ đường, miếu nhỏ và wind-chime post.
- **Đấu trường:** nền đá/cỏ, tường đổ, trụ đá, bậc thang và cổng phong ấn.

Yêu cầu:

- Pivot hợp lý, snap theo grid, scale thống nhất, apply transform, không negative scale.
- Tạo biến thể bằng hình khối và màu; không tăng asset count bằng các bản sao gần như giống nhau.
- Collider đơn giản tách khỏi visual mesh; cây, hoa và đồ trang trí nhỏ không dùng collider phức tạp.
- Dùng MultiMesh/instancing cho tre, cỏ, hoa, đá nhỏ và prop lặp lại.
- Giữ đường đi, điểm nhảy, khoảng né và tầm nhìn chiến đấu đúng với layout hiện có.

### 8. Vật liệu, shader, ánh sáng và VFX

- Rà `shaders/toon.gdshader`, `outline.gdshader`, `water.gdshader`, `sky.gdshader` trước khi thay.
- Chuẩn hóa palette material để nhiều asset có thể dùng chung.
- Toon shader có 2–3 dải sáng, shadow mềm vừa phải, rim light rất nhẹ và outline tùy chọn theo khoảng cách.
- Outline không được rung, vỡ ở cạnh gần hoặc làm nhân vật thành nét đen quá dày.
- Nước có màu turquoise, chuyển động chậm, foam tiết chế ở bờ.
- VFX Phong Trảm và Toàn Phong dùng ribbon/mesh/particle màu mint-cyan, ít overdraw, không che silhouette.
- Telegraphed attack của Trúc Tướng phải nhìn rõ: vòng cam/vàng mỏng trên mặt đất.
- Thiết lập WorldEnvironment với bầu trời xanh, mây stylized, fog nhẹ theo vùng và color grading giữ màu da cùng màu áo ổn định.

### 9. Pipeline Blender → Godot

- Dựng và kiểm tra qua Blender MCP; lưu file nguồn vào đúng cấu trúc `art/`.
- Cập nhật hoặc bổ sung script trong `tools/blender/` để asset có thể tái tạo trong background mode.
- Tên object, bone, action và material phải ổn định, dùng snake_case.
- Mesh sạch: không mặt trùng, không normal ngược, không orphan data, không n-gon gây lỗi export.
- Apply scale/rotation trước export; triangulate khi cần; kiểm tra tangent và normal.
- Export GLB vào đúng đường dẫn runtime hiện có. Không thay đường dẫn hàng loạt nếu có thể giữ tương thích.
- Sau import, kiểm tra orientation, scale, root motion, animation loop, socket kiếm, material assignment và collider.
- Nếu Godot import tạo file phụ, đảm bảo repo có quy tắc commit phù hợp.

### 10. Hiệu năng

Mục tiêu mặc định:

- 60 FPS ở 1920×1080, preset Medium trên PC phổ thông có GPU rời tầm trung.
- Không vượt ngân sách draw call và VRAM chỉ để bám ảnh concept.
- Có culling, LOD hoặc impostor hợp lý cho tre, cây và cảnh xa.
- Hạn chế transparent material và particle overdraw.
- Ánh sáng tĩnh ưu tiên baked hoặc giải pháp rẻ phù hợp Godot GL Compatibility; ánh sáng động chỉ dùng tại điểm cần thiết.

Đo ít nhất tại:

- Quảng trường làng nhìn về cổng.
- Trúc Hải nhìn qua cầu.
- Khe Gió khi đang khinh công.
- Trận Trúc Tướng lúc có telegraph và VFX.

Nếu máy kiểm thử khác mục tiêu, ghi rõ cấu hình và số đo thực tế.

### 11. Kiểm tra và tiêu chí hoàn thành

Không đánh dấu hoàn thành chỉ vì GLB đã export. Mỗi nhóm asset phải đạt:

- Hiển thị đúng trong Godot runtime.
- Animation, socket, collider và gameplay không bị hỏng.
- Không có missing material, texture hoặc đường dẫn tuyệt đối.
- Silhouette và palette gần ảnh tham chiếu khi nhìn từ camera gameplay.
- Không có clipping nghiêm trọng trong animation chính.
- Cảnh không bị rỗng, nhưng đường đi và vùng chiến đấu vẫn rõ.
- Test hiện có của repo tiếp tục chạy; bổ sung kiểm tra chỉ khi nó phát hiện được lỗi pipeline thực tế.

Tạo ảnh so sánh có cùng camera trước/sau cho từng vùng. Ghi các sai khác còn lại và nguyên nhân kỹ thuật.

### 12. Kết quả phải bàn giao

- File `.blend`, `.glb`, material, texture và script generator đã cập nhật.
- Scene kiểm thử và các scene runtime đã tích hợp.
- `docs/roblox-art-direction.md`: palette, tỷ lệ, material, lighting, modular rules và ảnh mẫu.
- `docs/visual-upgrade-progress.md`: asset đã hoàn thành, trạng thái tích hợp, ngân sách, FPS và vấn đề còn lại.
- Ảnh preview trước/sau ở cùng camera.
- Báo cáo cuối gồm:
  - File đã thay đổi.
  - Asset đã tạo/thay.
  - Kết quả test và hiệu năng.
  - Những phần chưa đạt ảnh tham chiếu.
  - Ba bước ưu tiên tiếp theo.

Hãy bắt đầu bằng việc audit ngắn gọn repo, xác định chính xác file sẽ tác động, rồi triển khai prototype Lâm An và lát cắt làng. Không mở rộng sang toàn bộ bản đồ trước khi prototype được kiểm tra trong Godot.
