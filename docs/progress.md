# Tiến độ

Cập nhật: 21/10/2026. Nhánh `claude/p1-combat-core` (giai đoạn 1 của kế hoạch mở rộng thành Chương I hoàn chỉnh). Đọc file này đầu mỗi phiên để biết đang ở đâu.

## Tổng quan theo mốc

| Mốc | Trạng thái |
|---|---|
| 1. Khảo sát bản nền, công cụ, kế hoạch | Xong |
| 2. Đoạn chơi mẫu 20–30 phút (Bến Vân Khê → Trúc Hải) | Xong về nội dung và test tự động; **chưa có người chơi thử thật** và **chưa đo hiệu năng trên GPU thật** |
| 3. Hoàn thiện chương (Hồi 3, đủ nhiệm vụ, boss cuối) | Chưa bắt đầu |
| 4. Đóng gói Windows | Đã có export preset, script tải template có kiểm tra SHA-512, bản build tạo được; **chưa chạy thử trên máy Windows** |
| 5. Bản Web trên Vercel | Xong: preset Web không luồng, `tools/build_web.sh`, `vercel.json`; smoke test Chromium PASS; bản build 51 MB |
| 6. Đồ họa theo concept | Xong: rừng dày (13 loài cây, cụm, vùng cấm), trời cel, núi đá vôi, nước, preset Thấp/Trung bình/Cao, 10 đạo cụ làng/đền, Lâm An và Trúc Tướng theo ảnh concept, hạt bay theo vùng, vệt kiếm |
| 7. Ngũ hành kiếm quyết | Xong: 5 hệ × E/Q/X, 6 trạng thái, nộ khí, tuyệt kỹ, 4 kiếm nguyên tố, 2 clip mới, SFX |
| 8. Chơi dài hạn | Xong: Ải Vô Tận, Cảnh giới 1–5 và tinh anh, Kỳ Ngộ (công khai tỉ lệ, bảo hiểm), rương thưởng, kiếm có chỉ số, trang phục, nhiệm vụ ngày, điểm danh 7 ngày; save v3 + hồ sơ dùng chung |
| 9. Mở rộng GĐ1 — lõi combat | Xong: trạng thái/buff/debuff trên người chơi có icon HUD, vật phẩm tiêu hao theo dữ liệu + ô nhanh (C) + quầy thuốc, 13 chỉ số mới + bảng Nhân vật, Ngọc bội (3 ô, 4 bộ), 6 phản ứng nguyên tố, phá thế + kết liễu (F), Tâm Nhãn (né/phản hoàn hảo làm chậm địch); hồ sơ v2 |
| 10. Mở rộng GĐ2–6 | Chưa làm: thời tiết + ngày–đêm + tông tối (GĐ2), quái mới (GĐ3), bản đồ phía bắc (GĐ4), Hồi 3 + boss cuối (GĐ5), cân bằng và phát hành (GĐ6) |

## Đã xong trong đoạn chơi mẫu

- **Thế giới:** bản đồ hữu hạn 4 vùng (Bến Vân Khê, Đồi Gió, Trúc Hải, khu đền), sông, suối, Khe Gió sâu 30 m, sống núi, núi nền; 107 đạo cụ đặt cố định; 12 điểm khám phá; streaming vùng trên worker thread; navmesh theo khu giao tranh.
- **Nhân vật:** Lâm An có rig 20 khớp và 20 animation (idle, đi, chạy, nhảy, rơi, tiếp đất, né, 3 đòn combo, trọng kích, 2 kỹ năng, đỡ, phản đòn, trúng đòn, chết, khinh công, lướt, tương tác). 5 NPC (Tiểu Mạc, bà Lục, chú Bảy, bà Hạnh, Tịch Phong) + dân làng đổi màu.
- **Chiến đấu:** combo 3 đòn, trọng kích, né có khung bất tử, đỡ/phản đòn, Phong Trảm, Toàn Phong, thể lực, khóa mục tiêu, hit-stop, rung camera, báo trước đòn. Thời điểm gây sát thương dùng chung với animation (`data/anim_timings.json`).
- **Địch:** Tàn binh (cận chiến, theo trại), Heo gió (lao tới), Trúc Tướng (miniboss 2 pha).
- **Nhiệm vụ:** 4 chính, 2 phụ, 2 sự kiện; 25 nút hội thoại tiếng Việt; câu đố chuông gió; kết đoạn có thị kiến và mở ý Hồi 3.
- **Tiến trình:** cấp, điểm tu luyện nâng kỹ năng, 3 thanh kiếm, thuốc hồi máu, túi đồ, Miếu Gió (checkpoint, hồi máu, đặt lại trại địch).
- **UI:** màn hình chính, tạm dừng, bản đồ, nhật ký, túi đồ, thiết lập (đổi phím, chuột, âm lượng 3 bus, rung camera, chất lượng, toàn màn hình), ghi công/giấy phép, HUD gỡ lỗi F3.
- **Âm thanh:** 7 bản nhạc theo vùng/chiến đấu/boss, 4 âm nền, 90 hiệu ứng (bước chân theo bề mặt, kiếm, phản đòn, quái, UI).
- **Lưu game:** schema v2, migrate từ v1, backup, phục hồi file hỏng, tự lưu ở mốc an toàn.
- **Kiểm thử:** smoke test (bản nền, giữ nguyên độ bao phủ) và gameplay test chơi trọn đoạn mẫu từ New Game đến kết. Xem [validation.md](validation.md).

## Review mã và sửa lỗi (14/10)

Review tự động theo 4 nhóm (người chơi/chiến đấu, địch/thế giới, dữ liệu nhiệm vụ, save/UI), mỗi phát hiện được đối chiếu lại với code trước khi sửa. Đã sửa:

- **Chặn tiến trình:** dọn trại tàn binh, nghe tiếng vọng, đọc nhật ký, mở rương hay hạ boss *trước* khi nhiệm vụ yêu cầu giờ vẫn được tính (QuestManager đọc lại các "sự kiện một lần" từ GameState); trigger vẫn kích hoạt nếu người chơi đã đứng sẵn trong vùng.
- **AI:** tàn binh chỉ lượn vòng mà không áp sát (lỗi token tấn công); địch dùng navmesh của khu khác hoặc đứng im ở mép navmesh; tường gió bị bake vào navmesh làm boss kẹt; hit-stop làm lệch thời điểm đòn của địch; heo trượt xa sau khi bị phản; khối va chạm heo không xoay theo hướng; sóng xung kích vẫn gây sát thương sau khi boss chết; vòng báo đòn nện lệch vùng sát thương thật; phản lưỡi gió từ xa làm boss choáng.
- **Người chơi:** chết vì sát thương xuyên đỡ không kích hoạt; nút đỡ/đánh bị "kẹt" sau khi tạm dừng hoặc hội thoại; thể lực không hồi sau khi chạy rồi đánh; animation tiếp đất mạnh không bao giờ chạy; nhấn đỡ trong lúc bất tử sau hồi sinh vẫn bị đánh; Phong Trảm trúng hai lần ở cự ly gần.
- **Luồng game:** tải save trong màn hình gục ngã bị hồi sinh đè lên; bắt đầu game mới giữa trận boss giữ nguyên trạng thái trận; mở hội thoại/thị kiến/miếu giữa lúc giao chiến.

## Giai đoạn 1 — lõi combat mở rộng (18–21/10)

- **Trạng thái trên Lâm An:** cùng luật `StatusEffects` với địch, thêm loại `buff`/`debuff`, cộng chỉ số khi đang có. Debuff: Trúng độc (chặn hồi máu), Chảy máu (né rũ bớt lớp), Choáng, Suy nhược, Lãng quên; buff: Cường lực, Kim cang, Khinh thân, Tịnh tâm, Hồi xuân, Ôn dương. Hàng icon trên thanh máu. Trạng thái đứng yên khi hội thoại/thị kiến khóa điều khiển.
- **Vật phẩm:** `data/items.json` có `effect` (hồi máu, buff, giải trạng thái); R dùng thuốc mạnh nhất, C dùng ô nhanh chọn trong Túi đồ. 6 đan dược mới. Quầy thuốc Ông Lang Vân ở quảng trường làng (`data/shops.json`).
- **Chỉ số:** phòng ngự, xuyên giáp, hút máu, tốc độ ra đòn, kháng từng nguyên tố, kháng trạng thái, thể lực tối đa, hồi thể lực, sức phá thế, tốc độ di chuyển, hiệu quả hồi phục, sát thương phản ứng. Địch có `defense` số. Tab **Nhân vật** trong Túi đồ.
- **Ngọc bội:** 3 ô Thiên/Địa/Nhân, 12 món thuộc 4 bộ (hiệu ứng 2 và 3 món), rơi từ địch/tinh anh/boss/rương, phân giải ra Đồng; lưu trong hồ sơ (v1 → v2 tự migrate, không mất dữ liệu cũ).
- **Phản ứng nguyên tố** (`data/reactions.json`): Vỡ Băng, Điện Giật, Hỏa Lốc, Bốc Hơi, Đông Kết, Lôi Phong.
- **Phá thế + kết liễu:** hết thế thì địch loạng choạng ≥ 2,2 s, thanh thế trên đầu; F để kết liễu (boss chỉ mất tối đa 12% máu, cửa sổ 1,5 s). Nhiệm vụ ngày "Kết liễu".
- **Tâm Nhãn:** né trong 0,15 s đầu hoặc đỡ trong 0,1 s đầu khi đòn địch tới → chỉ địch chậm ×0,3 trong 1,5 s, đòn kế tiếp ×1,5, hồi 4 s.
- **Hạ tầng cho địch mới:** `EnemyFactory`, `AreaEffect` dùng được cho địch, âm báo đòn `start_sfx`, `max_attackers`, tô màu theo dữ liệu, số sát thương theo thời gian.
- **Sửa lỗi có từ trước:** tuyệt kỹ Thủy và Băng Tiễn đọc tốc độ đạn thành tốc độ phát clip (bất tử của Đại Hải Triều chỉ ~0,1 s) — tách khóa `missile_speed`.
- Test: 353 check (combat 152, progression 118), tất cả PASS.

## Đang làm / làm tiếp ngay

1. Chơi thử bản Web trên link preview Vercel và trên Windows: cảm giác điều khiển, độ khó các đợt Ải, nhịp Ngọc Gió (ước tính ~400–600 mỗi ngày chơi đều, tức một lượt ×10 sau 3–4 ngày), chỗ lạc đường.
2. Đo hiệu năng 1080p Medium trên GPU thật bằng `./tools/run.ps1 -Mode preview` (làng đông, chuyển vùng, trận boss) và ghi vào `validation.md`.
3. Chạy bản build `build/windows/VanKhe.exe` trên Windows sạch (không có Godot/Blender).

## Lỗi và giới hạn đã biết

- Nhạc soạn bằng code và render qua soundfont General MIDI: dùng được nhưng nên được người có chuyên môn nghe duyệt; coi là **bản tạm có thể thay**.
- Chưa có lồng tiếng (đúng phạm vi chương đầu).
- Model low-poly dựng bằng script, không texture vẽ tay; mặt/tóc còn đơn giản. Animation keyframe tay; các đòn chính nên được animator chỉnh lại.
- Cân bằng Ải Vô Tận và Cảnh giới mới qua test tự động, chưa qua người chơi thật; số liệu nằm hết trong `data/*.json` để chỉnh nhanh.
- Bản Web tải ~51 MB (wasm 39,5 MB, pck 12,7 MB) trước khi nén; Vercel nén khi truyền.
- Chỉ có 2 loại địch thường + 1 miniboss (mục tiêu chương: 6 mẫu thuộc 4 nhóm — thiếu nhóm đánh xa và hộ vệ nặng).
- 5/6 phản ứng nguyên tố cần hai nguồn nguyên tố; một thanh kiếm chỉ có một hệ nên hiện chỉ tự làm được Vỡ Băng. Mưa (GĐ2) và quái gây trạng thái (GĐ3) sẽ mở phần còn lại.
- Ngọc bội đang đeo áp dụng cho mọi bản lưu, kể cả hành trình mới.
- Điều khiển chỉ hỗ trợ bàn phím + chuột; chưa hỗ trợ gamepad.
- Hiệu năng chỉ đo được trên renderer phần mềm (llvmpipe) trong môi trường phát triển, không có ý nghĩa cho mục tiêu 60 FPS.

## Bước tiếp theo

Theo kế hoạch đã duyệt (6 giai đoạn, mỗi giai đoạn một PR):

1. **GĐ2:** thời tiết (mưa + sấm sét, sương mù, gió bão), ngày–đêm 24 phút, tông tối khi xấu trời/đêm; ảnh hưởng nhẹ gameplay; save v4.
2. **GĐ3:** cung thủ, hộ vệ khiên, bầy sói đêm + sói đầu đàn, hồn ảnh ký ức, pháp sư tàn binh, khôi lỗi đá.
3. **GĐ4:** bản đồ nối dài phía bắc (Sơn Đạo, Hắc Lâm, Nội Điện) + hang riêng.
4. **GĐ5:** Hồi 3, boss cuối Tịch Phong 3 pha, kết thường / kết thật (đủ 5 Tơ ký ức).
5. **GĐ6:** cân bằng, hiệu năng, tài liệu, phát hành.
