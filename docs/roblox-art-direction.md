# Hướng mỹ thuật Roblox cho Vân Khê

Tham khảo: năm concept và brief trong `art/reference/roblox/`. Đây là bản chuyển ngôn ngữ hình khối vào game Godot hiện tại; không chuyển game sang Roblox Studio.

- Nhân vật: đầu và tay chân dạng khối bo cạnh, mắt hổ phách, tóc đen thành mảng lớn, áo ngọc bích, cổ kem, đai đỏ và phụ kiện vàng. Giữ bộ xương 20 khớp và toàn bộ clip cũ để bảo toàn combat.
- Làng: mái ngói xếp lớp, gỗ nâu, tường kem, đèn lồng đỏ; giếng đá có lòng nước, sạp có khay hàng và mép bạt. Dùng lại footprint và collider của kit cũ.
- Thiên nhiên: tán lá khối, thân trúc có đốt rõ, vách đá chia tầng và núi karst thành cụm khối có đỉnh cỏ. Giữ bố trí thế giới, vùng tương tác và đường đi.
- Render: ba mức sáng toon, giảm viền và rim, tắt nhiễu sơn; sửa vertex color và phép nhân ánh sáng để tránh mất màu. Ánh sáng nền có giới hạn, vẫn đổi theo đêm và thời tiết.

Lâm An có 8.718 tam giác, 6 material: 5 kênh đổi trang phục được giữ nguyên và một palette vertex color. Không ép xuống 4 material vì sẽ phá cơ chế skin đang dùng. NPC cũng giữ material mà dữ liệu runtime đổi màu. Không dùng atlas texture vì bộ asset dùng màu phẳng và vertex color; emissive được giữ riêng.

76 GLB đang dùng và nguồn Blender được xuất lại. Nhân vật người, mái nhà, giếng, sạp, tán cây và đá được sửa hình học; một số đạo cụ, vũ khí và Heo gió giữ hình học cũ, hưởng thay đổi màu/shader chung. Ba model legacy không dùng được giữ nguyên. UI, icon và audio nằm ngoài đợt sửa model này.

Giới hạn còn lại: mức chi tiết chưa ngang tranh concept; chưa có LOD mới cho nhân vật, atlas, hoặc toàn bộ biến thể modular trong brief. Tóc, hoa văn trang phục, foliage và VFX boss còn có thể được trau chuốt thêm. Đây là các đề xuất cho lượt art tiếp theo, không phải tính năng đã hoàn thành.
