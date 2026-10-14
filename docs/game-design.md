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
| Phong Trảm | E; lưỡi gió bay xa (đạn) |
| Toàn Phong | Q; xoáy kiếm quanh người, nhiều lần trúng |
| Khóa mục tiêu | Chuột giữa / T |
| Khinh công | Space trên không để bật nhảy; giữ Space khi rơi để lướt |

Hệ thống có thể lực, hitbox/hurtbox theo cung quét, báo trước đòn đánh (vòng đỏ dưới đất), hit-stop, rung camera (giảm được trong cài đặt), số sát thương.

Kẻ địch:

- **Tàn binh mặt nạ** — cận chiến, đi theo nhóm; mỗi trại tối đa 2 kẻ được tấn công cùng lúc.
- **Heo gió** — lấy đà rồi húc thẳng; đâm vào tường sẽ choáng.
- **Trúc Tướng** (miniboss) — 950 máu, 3 đòn (chém, quét, nện đất có sóng xung kích); dưới 50% máu gầm lên, bất tử ngắn rồi sang pha 2 với lưỡi gió. Thua thì đấu trường mở lại, boss hồi máu; thắng thì không hồi sinh.

Chưa có: địch bắn xa, địch khiên nặng, boss hai pha cuối chương (Hồi 3).

## Phát triển nhân vật

- Lên cấp theo bảng `XP_CURVE` (`scripts/core/game_state.gd`); mỗi cấp +14 máu, +1,5 công và 1 điểm tu luyện để nâng kỹ năng (tối đa bậc 3) trong Túi đồ.
- Kiếm: Kiếm Cũ (10) → Thanh Trúc Kiếm (16) → Phong Ngân Kiếm (24).
- Hồi máu: Bánh ngải, Trà sen (phím R). Miếu Gió hồi đầy máu, làm điểm hồi sinh, lưu tự động và đặt lại trại địch.
- Vật phẩm nhiệm vụ / chìa khóa: thư, chuông gió, nhật ký, Lông vũ gió, Tơ ký ức, Ngọc phong ấn.

Không có gacha. Nếu muốn thêm cần chủ dự án duyệt trước.

## Giao diện

Toàn bộ tiếng Việt. Màn hình chính (Mới / Tiếp tục), tạm dừng, bản đồ, nhật ký nhiệm vụ, túi đồ (kỹ năng, kiếm), cài đặt (đổi phím, độ nhạy chuột, đảo trục Y, âm lượng Nhạc/Hiệu ứng/Âm nền, giảm rung camera, chất lượng Thấp/Trung bình/Cao, toàn màn hình, số sát thương, HUD gỡ lỗi F3). HUD co giãn theo độ phân giải (cơ sở 1280 × 720).
