# Thiết kế game — Vân Khê: Dư Âm Gió

Action RPG góc nhìn thứ ba, một người chơi, phong cách anime cel-shading pha võ hiệp. Bảng màu chủ đạo: ngọc bích, xanh trúc, kem; điểm nhấn đỏ son và vàng.

## Cốt truyện Chương I

Lâm An, kiếm khách trẻ mang thanh kiếm cũ, cập bến thung lũng Vân Khê. Người làng đang quên dần người thân; mỗi chiều có hồi chuông vọng từ núi. Lâm An nghe được ký ức trôi trong gió. Lần theo các tiếng vọng qua Trúc Hải, Lâm An tìm ra sự thật: người giữ đền Tịch Phong đã dùng ký ức — của mình, rồi của cả làng — để giữ một cơn bão bị phong ấn dưới núi suốt ba mươi năm.

| Hồi | Vùng | Trạng thái |
|---|---|---|
| 1 | Bến Vân Khê, làng, Đồi Gió | Có trong slice |
| 2 | Trúc Hải, trại tàn binh, Khe Gió, đấu trường Trúc Tướng | Có trong slice |
| 3 | Đền Tịch Phong (sau cổng phong ấn) | Chưa làm — cổng hiện báo "Hồi 3" |

## Vùng chơi

Bản đồ hữu hạn ~264 × 562 m, sinh từ `data/world/layout.json` (độ cao, khu bằng phẳng, đường, sông/suối, khe vực, sống núi) cộng nhiễu theo seed. Thứ tự từ nam lên bắc: bến sông → làng (quảng trường, lò rèn, Miếu Gió) → bãi heo rừng phía đông → Đồi Gió → bìa Trúc Hải → suối → trại tàn binh/trạm gác → Khe Gió (vực sâu 30 m, phải dùng khinh công) → bãi chuông gió → đấu trường → cổng phong ấn. Mỗi vùng có nhạc, âm nền, màu cỏ và không khí (sương, nắng) riêng.

## Nhiệm vụ

| ID | Loại | Tên | Tóm tắt |
|---|---|---|---|
| `mq01_ben_song` | Chính | Bến sông sương sớm | Lên làng, cứu người đưa thư Tiểu Mạc khỏi tàn binh |
| `mq02_lang_quen` | Chính | Làng quên tên | Đưa thư cho bà Lục, thắp Miếu Gió, hỏi dân làng; nhận Phong Trảm và bản đồ |
| `mq03_dau_ky_uc` | Chính | Dấu ký ức trong rừng trúc | Ba tiếng vọng ký ức (mở Toàn Phong), nhật ký ở trạm gác (mở khinh công) |
| `mq04_vuot_khe` | Chính | Vượt Khe Gió | Bay qua khe, gõ chuông theo lời ru, hạ Trúc Tướng, chạm lõi phong ấn |
| `sq01_chuong_gio` | Phụ | Chuông gió của bé Tý | Tìm chuông gió ở bãi heo rừng, trả bà Hạnh |
| `sq02_lo_ren` | Phụ | Lò rèn nguội lửa | Gom 3 Đá gió cho chú Bảy, nhận Thanh Trúc Kiếm; sau khi hạ Trúc Tướng có thể rèn Phong Ngân Kiếm bằng Ngọc phong ấn |
| `ev01_chan_duong` | Sự kiện | Tàn binh chặn đường | Phục kích trên Đồi Gió khi đã nhận `mq03` |
| `ev02_tieng_sao` | Sự kiện | Tiếng sáo bên suối | Tiếng sáo dẫn tới rương ẩn bên suối |

Mỗi nhiệm vụ có nguyên nhân, kết quả, phần thưởng và nhiệm vụ kế tiếp trong `data/quests.json`. Phần thưởng gắn cờ `reward:<id>` nên không thể nhận hai lần; rương, tiếng vọng, boss và NPC đều có ID ổn định lưu trong save.

## Chiến đấu

| Thao tác | Mô tả |
|---|---|
| Chuỗi 3 đòn | Chuột trái; khung nối đòn và thời điểm gây sát thương lấy từ `data/anim_timings.json` (dùng chung với Blender) |
| Trọng kích | Giữ chuột trái 0,4 s; tốn thể lực, phá thế đỡ |
| Né | Shift; có khung bất tử 0,03–0,34 s |
| Đỡ / phản đòn | Chuột phải; bấm đúng lúc đòn tới (0,2 s đầu) để phản, làm địch choáng |
| Kiếm thức | E và Q: hai thức của hệ kiếm đang cầm (có hồi chiêu); X: tuyệt kỹ, tốn đầy thanh nộ khí |
| Khóa mục tiêu | Chuột giữa / T |
| Khinh công | Space trên không để bật nhảy; giữ Space khi rơi để lướt |

Hệ thống có thể lực, hitbox/hurtbox theo cung quét, báo trước đòn đánh (vòng đỏ dưới đất), hit-stop, rung camera (giảm được trong cài đặt), số sát thương, vệt kiếm màu theo hệ.

### Ngũ hành kiếm quyết

Mỗi thanh kiếm thuộc một hệ; hệ quyết định ba thức E/Q/X (`data/styles.json`, `data/attacks.json`). Nộ khí (0–100) tăng khi đánh trúng, phản đòn và bị đánh; tuyệt kỹ X làm chậm thời gian một nhịp và bất tử tới khi ra đòn.

| Hệ | Kiếm | E | Q | X | Trạng thái |
|---|---|---|---|---|---|
| Phong Ảnh Quyết | Kiếm Cũ, Thanh Trúc, Phong Ngân | Phong Trảm | Toàn Phong | Thiên Phong Lạc | Gió cuốn |
| Thủy Nguyệt Quyết | Thủy Nguyệt Kiếm | Lưu Thủy Trảm | Xoáy Nước | Đại Hải Triều | Ướt |
| Lôi Ảnh Quyết | Lôi Minh Kiếm | Lôi Thiểm | Lôi Võng | Thiên Lôi Giáng | Tê liệt |
| Viêm Dương Quyết | Xích Viêm Kiếm | Viêm Luân | Hỏa Long Toàn | Nhật Viêm Trảm | Thiêu đốt |
| Hàn Sương Quyết | Hàn Sương Kiếm | Băng Tiễn | Sương Giá Trận | Hàn Băng Thiên Kiếm | Lạnh cóng, 3 lớp thì đóng băng |

Có kiếm của hệ nào thì học được E và Q của hệ đó; X học bằng 2 điểm tu luyện khi đã có Q. Boss kháng trạng thái và không bị đóng băng.

Kẻ địch:

- **Tàn binh mặt nạ** — cận chiến, đi theo nhóm; mỗi trại tối đa 2 kẻ được tấn công cùng lúc.
- **Heo gió** — lấy đà rồi húc thẳng; đâm vào tường sẽ choáng.
- **Trúc Tướng** (miniboss) — 950 máu, 3 đòn (chém, quét, nện đất có sóng xung kích); dưới 50% máu gầm lên, bất tử ngắn rồi sang pha 2 với lưỡi gió. Thua thì đấu trường mở lại, boss hồi máu; thắng thì không hồi sinh.

Chưa có: địch bắn xa, địch khiên nặng, boss hai pha cuối chương (Hồi 3).

## Phát triển nhân vật

- Lên cấp theo bảng `XP_CURVE` (`scripts/core/game_state.gd`); mỗi cấp +14 máu, +1,5 công và 1 điểm tu luyện để nâng kỹ năng (tối đa bậc 3) trong Túi đồ.
- Kiếm cốt truyện: Kiếm Cũ (10) → Thanh Trúc Kiếm (16) → Phong Ngân Kiếm (24). Bốn kiếm nguyên tố (26–27) nhận khi lần đầu vượt đợt 5, 10, 15, 20 của Ải Vô Tận; bản có độ hiếm và chỉ số phụ đến từ Kỳ Ngộ và rương thưởng.
- Hồi máu: Bánh ngải, Trà sen (phím R). Miếu Gió hồi đầy máu, làm điểm hồi sinh, lưu tự động và đặt lại trại địch.
- Vật phẩm nhiệm vụ / chìa khóa: thư, chuông gió, nhật ký, Lông vũ gió, Tơ ký ức, Ngọc phong ấn.

## Chơi dài hạn

Chủ dự án đã duyệt (10/2026) thêm các vòng lặp dưới đây. Cốt truyện không đổi; mọi phần thưởng chỉ dùng tiền trong game.

- **Ải Vô Tận** (`data/trial.json`): bia đá cạnh Miếu Gió làng, mở sau "Làng quên tên". Đấu trường trên đỉnh núi ngoài tường thung lũng. Mỗi đợt đông và mạnh hơn (+12% máu, +6% sát thương mỗi đợt), tinh anh từ đợt 3, Trúc Tướng mỗi 5 đợt. Sau mỗi đợt chọn 1 trong 3 phúc lành (công lực, bạo kích, giảm sát thương, hồi chiêu…). Gục ngã hoặc rời Ải đều nhận đủ Ngọc Gió, Đồng, kinh nghiệm đã tích lũy; rương thưởng mỗi 5 đợt. Không lưu game giữa lượt, không ghi cờ cốt truyện.
- **Cảnh giới thế giới** (`data/world_tiers.json`): mở sau đoạn chơi mẫu, cấp 1–5. Địch và Trúc Tướng xuất hiện lại với máu ×1,7–7,5, sát thương ×1,35–3,2, nhiều kinh nghiệm và Đồng hơn, có tinh anh mang 1–3 ấn (`data/elites.json`). Hạ Trúc Tướng ở cấp cao nhất để mở cấp kế tiếp, nhận Ngọc Gió và Rương Cảnh Giới. Cấp 0 giữ nguyên trò chơi gốc.
- **Kỳ Ngộ** (`data/gacha.json`): banner ở màn hình chính và menu tạm dừng. Tỉ lệ Cực phẩm 1,5% (≈2,4% tính cả bảo hiểm), Hiếm 10%, Thường 88,5%. Bảo hiểm tăng dần từ lượt 60, chắc chắn ở lượt 70; mỗi 10 lượt chắc chắn có Hiếm. Cực phẩm 50% ra kiếm nổi bật, trượt thì lần sau chắc chắn. Màn hình công khai tỉ lệ, bảo hiểm và 50 lượt gần nhất. Trang phục trùng đổi thành Mảnh Kỳ Ngộ để đổi phần thưởng cố định.
- **Ngọc Gió** chỉ có từ Ải Vô Tận, boss cảnh giới, nhiệm vụ ngày và điểm danh 7 ngày; lần chơi đầu tặng đủ một lượt ×10. Không có giao dịch tiền thật.
- **Kiếm có chỉ số** (`data/affixes.json`): Thường/Hiếm/Cực phẩm có 1/2/3 dòng (công lực, bạo kích, sát thương bạo kích, sát thương nguyên tố, tỉ lệ trạng thái, giảm hồi chiêu, nộ khí) và +0/10/20% công lực gốc.
- **Trang phục** (`data/skins.json`): đổi màu áo, đai, ruy băng của Lâm An; ánh kiếm đổi màu phần phát sáng của lưỡi.
- **Nhiệm vụ ngày** (`data/daily.json`): 4 nhiệm vụ mỗi ngày (hạ địch, tuyệt kỹ, phản đòn, trạng thái, rương, đợt Ải…), thưởng thêm khi xong cả 4.

Tiền, bảo hiểm, kho kiếm, trang phục, kỷ lục Ải và nhiệm vụ ngày nằm trong hồ sơ dùng chung `user://profile.json`, không thuộc bản lưu nào.

## Giao diện

Toàn bộ tiếng Việt. Màn hình chính (Mới / Tiếp tục / Kỳ Ngộ / Nhiệm vụ ngày / Kho kiếm & trang phục), tạm dừng (thêm Cảnh giới thế giới, Rời Ải Vô Tận), bản đồ, nhật ký nhiệm vụ, túi đồ (kỹ năng theo hệ, kiếm), cài đặt (đổi phím, độ nhạy chuột, đảo trục Y, âm lượng Nhạc/Hiệu ứng/Âm nền, giảm rung camera, chất lượng Thấp/Trung bình/Cao, toàn màn hình, số sát thương, HUD gỡ lỗi F3). HUD co giãn theo độ phân giải (cơ sở 1280 × 720).
