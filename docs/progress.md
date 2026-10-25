# Tiến độ

Cập nhật: 25/10/2026. Nhánh `claude/ui-skills-web-monsters` (giao diện mới, Kiếm Quyết 6 hệ theo nhiệm vụ, 7 quái mới, bản Web mượt hơn). Đọc file này đầu mỗi phiên để biết đang ở đâu.

## Tổng quan theo mốc

| Mốc | Trạng thái |
|---|---|
| 1. Khảo sát bản nền, công cụ, kế hoạch | Xong |
| 2. Đoạn chơi mẫu 20–30 phút (Bến Vân Khê → Trúc Hải) | Xong về nội dung và test tự động; **chưa có người chơi thử thật** và **chưa đo hiệu năng trên GPU thật** |
| 3. Hoàn thiện chương (Hồi 3, đủ nhiệm vụ, boss cuối) | Chưa bắt đầu |
| 4. Đóng gói Windows | Đã có export preset, script tải template có kiểm tra SHA-512, bản build tạo được; **chưa chạy thử trên máy Windows** |
| 5. Bản Web trên Vercel | Xong: preset Web không luồng, `tools/build_web.sh`, `vercel.json`; smoke test Chromium PASS; bản build 51 MB |
| 6. Đồ họa theo concept | Xong: rừng dày (13 loài cây, cụm, vùng cấm), trời cel, núi đá vôi, nước, preset Thấp/Trung bình/Cao, 10 đạo cụ làng/đền, Lâm An và Trúc Tướng theo ảnh concept, hạt bay theo vùng, vệt kiếm |
| 7. Ngũ hành kiếm quyết | Xong: 6 hệ × E/Q/X (thêm Thổ — Nham Sơn Quyết), mỗi hệ mở bằng một nhiệm vụ, gắn hệ riêng cho từng ô, 9 trạng thái, nộ khí, tuyệt kỹ, 4 kiếm nguyên tố, 2 clip mới, SFX |
| 8. Chơi dài hạn | Xong: Ải Vô Tận, Cảnh giới 1–5 và tinh anh, Kỳ Ngộ (công khai tỉ lệ, bảo hiểm), rương thưởng, kiếm có chỉ số, trang phục, nhiệm vụ ngày, điểm danh 7 ngày; save v3 + hồ sơ dùng chung |
| 9. Mở rộng GĐ1 — lõi combat | Xong: trạng thái/buff/debuff trên người chơi có icon HUD, vật phẩm tiêu hao theo dữ liệu + ô nhanh (C) + quầy thuốc, 13 chỉ số mới + bảng Nhân vật, Ngọc bội (3 ô, 4 bộ), 6 phản ứng nguyên tố, phá thế + kết liễu (F), Tâm Nhãn (né/phản hoàn hảo làm chậm địch); hồ sơ v2 |
| 10. Mở rộng GĐ2 — thời tiết, ngày–đêm | Xong: đồng hồ 24 phút/ngày, 6 kiểu thời tiết theo vùng, khí quyển nhiều lớp (vùng × giờ × thời tiết), trời đêm có sao/trăng, mưa, sấm sét và sét đánh có báo trước, sương, gió bão, đèn lồng ban đêm, âm thanh mưa/bão/dế, ảnh hưởng nhẹ trong trận, nghỉ ở miếu, kiếm phụ đổi nhanh (V); save v4 |
| 11. Mở rộng GĐ3 — quái mới, Kiếm Quyết, giao diện | Xong: 7 quái mới (5 thường, 2 miniboss) có model/animation Blender và AI riêng, 4 nhiệm vụ phụ mới mở hệ, HUD và bảng Kiếm Quyết kiểu Roblox, vòng chọn hệ, bản Web mượt hơn (xem mục dưới) |
| 12. Mở rộng GĐ4–6 | Chưa làm: bản đồ phía bắc (GĐ4), Hồi 3 + boss cuối (GĐ5), cân bằng và phát hành (GĐ6) |

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

## Giai đoạn 3 — Kiếm Quyết 6 hệ, giao diện mới, quái mới, Web mượt hơn (24–25/10)

- **Kiếm Quyết tách khỏi thanh kiếm:** cầm kiếm không còn dạy hệ. 6 hệ, mỗi hệ mở bằng một nhiệm vụ (`data/styles.json` → `unlock`): Phong Ảnh — cốt truyện; Viêm Dương — *Lò rèn nguội lửa* (chú Bảy); Thủy Nguyệt — *Hồn trên bãi lau* (ông lái đò, hồn ảnh ở bãi lau); Lôi Ảnh — *Lôi sư trên Đồi Gió* (Tiểu Mạc, trại lôi sư + cung thủ + hộ vệ khiên, bùa sét ở tế đàn); Hàn Sương — *Bầy sói sương* (thợ săn A Lực, Khe Sương, sói đầu đàn); Nham Sơn (Thổ, mới) — *Khôi lỗi giữ đền* (bia đá cổ phía đông, khôi lỗi đá). Mỗi ô E/Q/X gắn hệ riêng (`GameState.loadout`, lưu trong save; save cũ tự suy ra từ kiếm). Trùng hệ với kiếm đang cầm: +15% sát thương.
- **Hệ Thổ:** Địa Liệt Trảm (hàng gai đá lao về trước, kiểu `fissure`), Thạch Giáp Trận (sóng chấn + khiên đá giảm 30% sát thương nhận), Sơn Băng Địa Liệt (3 đợt địa chấn, Nứt giáp 3 tầng). Trạng thái Nứt giáp (−18 phòng ngự mỗi tầng), Sa lầy; 3 phản ứng mới: Sa Lầy (Thổ + Ướt), Nham Hỏa (Thổ + Thiêu đốt), Cát Lốc (Phong + Nứt giáp) — tổng 9.
- **Giao diện kiểu Roblox:** khung bo tròn có gờ nổi, nút nổi, chữ viền; HUD mới — huy hiệu hệ, thanh máu có vệt mất máu, thanh thể lực/kinh nghiệm, viên thuốc và ô nhanh, bản đồ nhỏ góc phải, 3 ô kỹ năng tròn có biểu tượng hệ, vòng hồi chiêu và số giây, chấm bậc; thanh máu boss và miniboss ở giữa trên; lời nhắc có phím riêng; toast dạng viên; dải banner. Bảng **Kiếm Quyết (K)**: 6 huy chương hệ, chiêu đang gắn, mô tả, nâng bậc, gắn vào ô, "Trang bị cả bộ", bảng tương tác nguyên tố. **Vòng chọn hệ (giữ Tab)**: rê chuột hoặc 1–6, thời gian chậm ×0,3 khi mở.
- **7 quái mới** (model + animation Blender, âm thanh tổng hợp): Cung thủ (giữ cự ly, bắn đón đầu), Hộ vệ khiên (đỡ phía trước, trọng kích/Thổ phá khiên), Lôi sư (dịch chuyển, cầu sét, gọi sét có báo trước), Sói sương (bầy, vồ; ban đêm có bầy lảng vảng ở Khe Sương), Sói đầu đàn (miniboss, hú tăng nộ cả bầy), Hồn ảnh (bay, chớp ra sau lưng, gào Suy nhược), Khôi lỗi đá (miniboss ngủ, 2 pha, nện vòng, ném đá, gai đá). Mỗi loại có gợi ý cách đánh lần đầu gặp. 4 khu mới: bãi lau, trại lôi sư, Khe Sương, phế tích phía đông.
- **Bản Web mượt hơn** (đo trong Chromium/WebAssembly, `?vkbench`): một vùng địa hình trước kia tính trọn trong một khung (26–38 ms trên Web; native ~36 ms trước khi tối ưu `WorldLayout`, nay ~19 ms) nay chia thành 6–8 lát, lát lâu nhất 4,5–5,6 ms; navmesh vùng giao tranh nạp từ bản dựng sẵn (~1,5–1,8 ms thay vì parse + bake đồng bộ 24–36 ms cho vùng nhỏ nhất); shader biên dịch trước sau màn hình chính; Lâm An và camera nội suy giữa hai bước vật lý; tự hạ độ phân giải 3D khi khung hình chậm.
- Test: 525 check (smoke 43, gameplay 70, combat 177, progression 120, world 92, monster 23 — bộ mới), tất cả PASS; web smoke PASS.

![Kiếm Quyết](screenshots/kiem_quyet.jpg)
![Vòng chọn hệ](screenshots/style_wheel.jpg)
![Quái mới](screenshots/bestiary.jpg)

## Giai đoạn 2 — thời tiết, ngày–đêm, kiếm phụ (21–23/10)

- **Đồng hồ:** 1 ngày = 24 phút thật (đêm ≈ 8 phút), đếm ngày, canh giờ trên HUD; tạm dừng là dừng. Nghỉ ở Miếu Gió đã thắp: "Nghỉ đến sáng / đến tối". Điều kiện `time:` / `weather:` cho thực thể và nhiệm vụ (quái đêm ở GĐ3).
- **Thời tiết:** quang, nhiều mây, mưa, giông bão, sương mù, gió lớn; bốc theo trọng số vùng bằng RNG lưu trong save; Ải luôn quang; thiết lập "Thời tiết động".
- **Hình:** `data/world/moods.json` — vùng × giờ × thời tiết; mặt trời/trăng quay theo giờ; trời có sao, trăng, mây bão, chớp; uniform toàn cục `vk_wind`/`vk_wet`/`vk_night`/`vk_gloom`/`vk_sky`; ngày quang ở làng giữ đúng màu cũ. Mưa bằng shader quanh camera (rẻ cho Web), sét xa + sét đánh có vòng báo trước, đèn lồng có ánh sáng ban đêm, lá bay trong gió bão.
- **Tiếng:** mưa nhẹ/nặng, gió bão, dế đêm, 4 tiếng sấm — tổng hợp bằng `build_sfx.py --weather`.
- **Trong trận:** mưa Lôi ×1,2, Hỏa ×0,8; bão Lôi ×1,3, Phong ×1,15, Hỏa ×0,8; mưa làm Ướt người và địch ngoài trời; sương/đêm thu tầm phát hiện của địch; hạ địch ban đêm +25% kinh nghiệm và Đồng.
- **Kiếm phụ:** chọn trong Kho kiếm, V để đổi (hồi 2,5 s); đòn trúng đầu tiên sau khi đổi +30% và chắc chắn gây trạng thái của kiếm mới → tự tạo phản ứng nguyên tố.
- **Save v4:** giờ, ngày, thời tiết + RNG, kiếm phụ; migrate từng bước v1 → v2 → v3 → v4.
- Test: 449 check (smoke 35, gameplay 48, combat 155, progression 119, world 92 — bộ mới), tất cả PASS.

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
- Quái: 7 loại thường + 3 miniboss/boss; cân bằng mới qua test tự động (AI, sát thương, luồng nhiệm vụ), chưa qua người chơi thật.
- Phản ứng nguyên tố: tự tạo bằng các ô gắn hệ khác nhau, kiếm phụ và mưa/bão (Ướt).
- Hiệu năng Web chỉ đo được trong Chromium headless dựng hình phần mềm (SwiftShader): số liệu chi phí script (`?vkbench`) đáng tin, FPS thì không — cần đo lại trên máy có GPU thật.
- Ngọc bội đang đeo áp dụng cho mọi bản lưu, kể cả hành trình mới.
- Điều khiển chỉ hỗ trợ bàn phím + chuột; chưa hỗ trợ gamepad.
- Hiệu năng chỉ đo được trên renderer phần mềm (llvmpipe) trong môi trường phát triển, không có ý nghĩa cho mục tiêu 60 FPS.

## Bước tiếp theo

Theo kế hoạch đã duyệt (6 giai đoạn, mỗi giai đoạn một PR):

1. **GĐ4:** bản đồ nối dài phía bắc (Sơn Đạo, Hắc Lâm, Nội Điện) + hang riêng.
2. **GĐ5:** Hồi 3, boss cuối Tịch Phong 3 pha, kết thường / kết thật (đủ 5 Tơ ký ức).
3. **GĐ6:** cân bằng, hiệu năng, tài liệu, phát hành.
