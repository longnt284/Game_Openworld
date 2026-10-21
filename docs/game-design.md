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
| Né | Shift; có khung bất tử 0,03–0,34 s; né trong 0,15 s đầu khi đòn địch tới là **né hoàn hảo** (Tâm Nhãn) |
| Đỡ / phản đòn | Chuột phải; bấm đúng lúc đòn tới (0,2 s đầu) để phản, làm địch choáng; 0,1 s đầu là **phản hoàn hảo** (Tâm Nhãn) |
| Kết liễu | F khi đứng trong 3 m quanh kẻ địch đã phá thế; ưu tiên hơn mọi tương tác khác |
| Kiếm thức | E và Q: hai thức của hệ kiếm đang cầm (có hồi chiêu); X: tuyệt kỹ, tốn đầy thanh nộ khí |
| Khóa mục tiêu | Chuột giữa / T |
| Khinh công | Space trên không để bật nhảy; giữ Space khi rơi để lướt |

Hệ thống có thể lực, hitbox/hurtbox theo cung quét, báo trước đòn đánh (vòng đỏ dưới đất), hit-stop, rung camera (giảm được trong cài đặt), số sát thương, vệt kiếm màu theo hệ.

**Phá thế và kết liễu:** mỗi đòn trừ thế (`poise`) của địch; hết thế thì địch **phá thế** — loạng choạng ít nhất 2,2 s (boss theo `break_stagger` riêng), nhận ×1,35 sát thương như mọi lần choáng. Thanh thế nhỏ trên đầu địch thường chỉ hiện khi đang khóa mục tiêu hoặc vừa trúng đòn (3 s); boss có thanh thế mảnh dưới thanh máu. Khi thanh chuyển vàng nhấp nháy, bấm F trong 3 m để **kết liễu** (`finisher` trong `data/attacks.json`): Lâm An lướt tới, bất tử tới hết đòn, gây tối thiểu max(công lực ×6, 45% máu tối đa) trước hệ số (đủ hạ gần như mọi kẻ thường), chậm thời gian một nhịp, +20 nộ khí. Boss chỉ kết liễu được trong 1,5 s đầu của lần phá thế và mất tối đa 12% máu tối đa mỗi lần. Kết liễu là trọng kích nên kích hoạt Vỡ Băng; có nhiệm vụ ngày "Kết liễu N lần".

**Tâm Nhãn:** né hoặc phản hoàn hảo một đòn địch (đòn chém, đạn, vùng, vòng chấn động) mở Tâm Nhãn: mọi kẻ địch — hoạt ảnh, đòn đánh, bước chạy, lao húc, đạn và vòng cảnh báo — chậm còn ×0,3 trong 1,5 s, Lâm An giữ nguyên tốc độ. Đòn kế tiếp thành đòn phản (×1,5); né hoàn hảo hoàn lại 20 thể lực. Màn hình phủ một lớp lạnh ở rìa, hiện chữ "Tâm Nhãn!" và vang một tiếng chuông. Hồi 4 s tính từ lúc mở (đang hồi thì né/phản hoàn hảo chỉ như né/phản thường); thời gian tính theo nhịp của Lâm An nên tạm dừng là dừng; chết, hồi sinh, tải game, về màn hình chính hay rời Ải đều trả thời gian về bình thường. Con số nằm ở `focus` trong `data/attacks.json`.

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

**Phối hợp nguyên tố** (`data/reactions.json`): đòn mang nguyên tố đánh vào kẻ địch đang có trạng thái hợp với nó gây một phản ứng, tên phản ứng hiện trên đầu địch:

| Phản ứng | Điều kiện | Hiệu ứng |
|---|---|---|
| Vỡ Băng | Đóng băng + trọng kích | ×1,5 sát thương, ×3 phá thế, hạ gục lại kẻ đang bị băng giữ; tan băng |
| Điện Giật | Ướt + Lôi | +40%; tê liệt và 25% sát thương lan sang mọi kẻ ướt trong 5 m |
| Hỏa Lốc | Gió cuốn + Hỏa | +20%; lốc lửa 4 m (60% sát thương), thiêu 2 lớp mọi kẻ trong lốc; hết Gió cuốn |
| Bốc Hơi | Lạnh cóng hoặc Đóng băng + Hỏa | ×1,8; tan hết lạnh và băng |
| Đông Kết | Ướt + Băng | đóng băng ngay (boss: thêm 2 lớp lạnh); hết Ướt |
| Lôi Phong | Gió cuốn + Lôi | +15%; sét nảy lần lượt sang 2 kẻ gần (60% sát thương, tê liệt); hết Gió cuốn |

Mỗi đòn gây tối đa một phản ứng, xét theo thứ tự bảng. Hệ số cộng dồn với hệ số sẵn có (Ướt vốn nhận Lôi ×1,3 → Điện Giật ×1,82; kẻ đang choáng nhận ×1,35). Sát thương lan không gây thêm phản ứng, không hút máu và không tăng nộ khí. Sát thương phản ứng (Ngọc bội Lôi Văn) tăng phần thêm của đòn và sát thương lan.

Kẻ địch:

- **Tàn binh mặt nạ** — cận chiến, đi theo nhóm; mỗi trại tối đa 2 kẻ được tấn công cùng lúc.
- **Heo gió** — lấy đà rồi húc thẳng; đâm vào tường sẽ choáng.
- **Trúc Tướng** (miniboss) — 950 máu, 3 đòn (chém, quét, nện đất có sóng xung kích); dưới 50% máu gầm lên, bất tử ngắn rồi sang pha 2 với lưỡi gió. Thua thì đấu trường mở lại, boss hồi máu; thắng thì không hồi sinh.

Chưa có: địch bắn xa, địch khiên nặng, boss hai pha cuối chương (Hồi 3).

## Phát triển nhân vật

- Lên cấp theo bảng `XP_CURVE` (`scripts/core/game_state.gd`); mỗi cấp +14 máu, +1,5 công và 1 điểm tu luyện để nâng kỹ năng (tối đa bậc 3) trong Túi đồ.
- Kiếm cốt truyện: Kiếm Cũ (10) → Thanh Trúc Kiếm (16) → Phong Ngân Kiếm (24). Bốn kiếm nguyên tố (26–27) nhận khi lần đầu vượt đợt 5, 10, 15, 20 của Ải Vô Tận; bản có độ hiếm và chỉ số phụ đến từ Kỳ Ngộ và rương thưởng.
- Hồi máu: Bánh ngải, Trà sen (phím R tự lấy món mạnh nhất). Thuốc khác (Kim Cang Đan, Bạo Huyết Đan, Khinh Thân Tán, Giải Độc Thảo, Hỏa Ôn Đan, Tịnh Tâm Trà) đặt vào ô nhanh trong Túi đồ rồi dùng bằng phím C; mua ở quầy thuốc Ông Lang Vân trên quảng trường làng, hoặc nhặt từ địch và rương thưởng. Miếu Gió hồi đầy máu, làm điểm hồi sinh, lưu tự động và đặt lại trại địch.
- Vật phẩm nhiệm vụ / chìa khóa: thư, chuông gió, nhật ký, Lông vũ gió, Tơ ký ức, Ngọc phong ấn.

## Chơi dài hạn

Chủ dự án đã duyệt (10/2026) thêm các vòng lặp dưới đây. Cốt truyện không đổi; mọi phần thưởng chỉ dùng tiền trong game.

- **Ải Vô Tận** (`data/trial.json`): bia đá cạnh Miếu Gió làng, mở sau "Làng quên tên". Đấu trường trên đỉnh núi ngoài tường thung lũng. Mỗi đợt đông và mạnh hơn (+12% máu, +6% sát thương mỗi đợt), tinh anh từ đợt 3, Trúc Tướng mỗi 5 đợt. Sau mỗi đợt chọn 1 trong 3 phúc lành (công lực, bạo kích, giảm sát thương, hồi chiêu, phòng ngự, hút máu, tốc độ ra đòn, sức phá thế…). Gục ngã hoặc rời Ải đều nhận đủ Ngọc Gió, Đồng, kinh nghiệm đã tích lũy; rương thưởng mỗi 5 đợt. Không lưu game giữa lượt, không ghi cờ cốt truyện.
- **Cảnh giới thế giới** (`data/world_tiers.json`): mở sau đoạn chơi mẫu, cấp 1–5. Địch và Trúc Tướng xuất hiện lại với máu ×1,7–7,5, sát thương ×1,35–3,2, nhiều kinh nghiệm và Đồng hơn, có tinh anh mang 1–3 ấn (`data/elites.json`). Hạ Trúc Tướng ở cấp cao nhất để mở cấp kế tiếp, nhận Ngọc Gió và Rương Cảnh Giới. Cấp 0 giữ nguyên trò chơi gốc.
- **Kỳ Ngộ** (`data/gacha.json`): banner ở màn hình chính và menu tạm dừng. Tỉ lệ Cực phẩm 1,5% (≈2,4% tính cả bảo hiểm), Hiếm 10%, Thường 88,5%. Bảo hiểm tăng dần từ lượt 60, chắc chắn ở lượt 70; mỗi 10 lượt chắc chắn có Hiếm. Cực phẩm 50% ra kiếm nổi bật, trượt thì lần sau chắc chắn. Màn hình công khai tỉ lệ, bảo hiểm và 50 lượt gần nhất. Trang phục trùng đổi thành Mảnh Kỳ Ngộ để đổi phần thưởng cố định.
- **Ngọc Gió** chỉ có từ Ải Vô Tận, boss cảnh giới, nhiệm vụ ngày và điểm danh 7 ngày; lần chơi đầu tặng đủ một lượt ×10. Không có giao dịch tiền thật.
- **Kiếm có chỉ số** (`data/affixes.json`): Thường/Hiếm/Cực phẩm có 1/2/3 dòng (công lực, bạo kích, sát thương bạo kích, sát thương nguyên tố, tỉ lệ trạng thái, giảm hồi chiêu, nộ khí; ít gặp hơn: tốc độ ra đòn, sức phá thế, xuyên giáp, hút máu, phòng ngự, kháng trạng thái, thể lực, hồi thể lực, tốc độ di chuyển, hiệu quả hồi phục) và +0/10/20% công lực gốc. Phòng ngự giảm sát thương theo 100/(100+phòng ngự); xuyên giáp bỏ qua phòng ngự của địch (địch cốt truyện không có phòng ngự). Tab **Nhân vật** trong Túi đồ liệt kê tổng mọi chỉ số (cấp, kiếm, Ngọc bội, phúc lành Ải, trạng thái đang có).
- **Ngọc bội** (`data/talismans.json`): 3 ô Thiên / Địa / Nhân trong Kho kiếm. 12 món thuộc 4 bộ — Phong Linh (hồi chiêu, nộ khí), Huyết Ngọc (hút máu, hồi phục), Kim Cương (phòng ngự, phá thế), Lôi Văn (nguyên tố, phản ứng). Mỗi món có 1 dòng chính (Hiếm ×1,3, Cực phẩm ×1,6) và 1/2/3 dòng phụ theo độ hiếm. Đeo 2 món cùng bộ mở hiệu ứng bậc 2, đủ 3 món mở thêm bậc 3. Rơi từ địch (3–4%, tinh anh ×3), boss (chắc chắn, độ hiếm cao hơn) và rương thưởng (Cảnh Giới chắc chắn, Tinh Anh 50%, Ải 25%); không có trong Kỳ Ngộ. Túi chứa 60 món; đầy thì món thấp bậc nhất tự phân giải. Phân giải: Thường 15, Hiếm 40, Cực phẩm 100 Đồng. Túi và ô đeo thuộc hồ sơ nên dùng chung mọi bản lưu, kể cả hành trình mới.
- **Trang phục** (`data/skins.json`): đổi màu áo, đai, ruy băng của Lâm An; ánh kiếm đổi màu phần phát sáng của lưỡi.
- **Nhiệm vụ ngày** (`data/daily.json`): 4 nhiệm vụ mỗi ngày (hạ địch, tuyệt kỹ, phản đòn, trạng thái, rương, đợt Ải…), thưởng thêm khi xong cả 4.

Tiền, bảo hiểm, kho kiếm, Ngọc bội, trang phục, kỷ lục Ải và nhiệm vụ ngày nằm trong hồ sơ dùng chung `user://profile.json`, không thuộc bản lưu nào.

## Giao diện

Toàn bộ tiếng Việt. Màn hình chính (Mới / Tiếp tục / Kỳ Ngộ / Nhiệm vụ ngày / Kiếm, Ngọc bội & trang phục), tạm dừng (thêm Cảnh giới thế giới, Rời Ải Vô Tận), bản đồ, nhật ký nhiệm vụ, túi đồ (kỹ năng theo hệ, kiếm), cài đặt (đổi phím, độ nhạy chuột, đảo trục Y, âm lượng Nhạc/Hiệu ứng/Âm nền, giảm rung camera, chất lượng Thấp/Trung bình/Cao, toàn màn hình, số sát thương, HUD gỡ lỗi F3). HUD co giãn theo độ phân giải (cơ sở 1280 × 720).
