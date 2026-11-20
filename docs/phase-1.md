# Phase 1 — PRD‑0

## Giả định thiết kế

- Đảo Bến là mặt tròn bán kính 34 m. Mây bị chặn trước mép đảo và không bị phạt rơi. Nhảy thay đổi trục Y. Nhặt đom đóm, nạp đèn, tỏa sáng và va chạm dùng khoảng cách XZ như contract.
- Mây có 3 ngọn lửa, giữ tối đa 10 đom đóm. Đèn cần 5 đom đóm và có thể nạp dần. Khi có nhiều đèn trong tầm, `E` nạp vào đèn chưa sáng gần nhất, ưu tiên ID nhỏ hơn nếu bằng khoảng cách.
- Thứ tự một bước là di chuyển, nhặt, nạp, tỏa sáng, cập nhật địch và xét kết thúc. Nếu nạp đèn cuối, chiến thắng được chốt ngay trong bước đó. Tới bình minh ở 180 giây hoặc hết lửa thì thua. Thưởng thời gian và lửa chỉ cộng khi thắng.
- Mỗi hit làm rơi `floor(carried × hit_drop_ratio)` đom đóm. Đom đóm đánh rơi bị mất. Mây bất tử 1,25 giây sau lần trúng đòn. Tỏa sáng tiêu đom đóm khi đủ chi phí và hết hồi chiêu, kể cả khi không có Bóng Mực trong tầm. Mỗi Bóng Mực bị ảnh hưởng tính một lần điểm cho lần tỏa sáng đó.
- Game mặc định có 60 đom đóm từ seed, gồm các cụm trên đường tới đèn. Khi còn dưới 32 đom đóm, game kiểm tra bổ sung 6 con mỗi 4 giây. Bóng Mực mặc định xuất hiện sau 5, 13, 24 và 40 giây. Danh sách `motes` thay thế đàn mặc định. Danh sách `shades` thay thế đàn mặc định và tắt các đợt sinh tự động trừ khi scenario bật rõ `random_shades: true`. `lit: true` với `deposited` bỏ trống đặt mức nạp bằng chi phí đèn, không ghi sự kiện hoặc điểm khi dựng scenario.
- Lượt chơi lại giữ seed. Khởi động lại ứng dụng chọn seed mới. Đồ họa và âm thanh được tạo trực tiếp trong dự án.

## Tiêu chí nghiệm thu và kết quả

| Yêu cầu | Cách kiểm chứng | Kết quả |
|---|---|---|
| Mây nhảy, di chuyển bằng input; góc camera điều khiển hướng di chuyển | Lượt chơi qua scene Godot, `test_movement_rotation_normalization_and_jump_edge` | Đạt. Hướng theo camera được kiểm tra bằng input yaw 90° trong headless |
| Đom đóm nhặt được, sức chứa hữu hạn, nạp từng phần hoặc thắp đủ | `test_pickup_cap_horizontal_radius_and_partial_deposit`, `thap-den.json` và lượt chơi qua scene | Đạt |
| Bóng Mực sinh ra, đuổi, gây mất lửa và sợ đèn đã thắp | `test_deterministic_jsonl_and_generated_ids`, `test_hit_drop_invulnerability_and_early_loss`, `test_safe_zone_blocks_shades_at_exact_boundary` | Đạt |
| Tỏa sáng trừ tài nguyên, đẩy và làm choáng trong bán kính, có hồi chiêu | `test_pulse_range_push_duration_cost_and_cooldown`, lượt chơi qua scene với phím Q và ảnh hiệu ứng | Đạt |
| HUD hiển thị thông tin; có thắng, thua và chơi lại | Lượt chơi qua scene, ảnh và các kịch bản điểm/thắng/thua | Đạt |
| JSONL có tick 0 và dòng `end`, dừng đúng tick, kết quả trùng từng byte, input sai trả mã 2 | Bộ kiểm chứng contract và hai lần xuất scenario mẫu | Đạt trên Windows |
| Chạy bằng lệnh trong contract trên máy chấm macOS hoặc Linux | Godot 4.4 với renderer Compatibility. Script Bash chọn Godot từ `PATH` hoặc `GODOT_BIN` | `build`, `headless` và `verify` đã chạy qua Git Bash trên Windows. Chưa chạy trên macOS hoặc Linux |

Xem [log contract](proof/phase-1/contract-tests.log), [log lượt chơi](proof/phase-1/playthrough.log), [ảnh bắt đầu](proof/phase-1/01-dao-ben.jpg), [ảnh đèn sáng](proof/phase-1/02-den-da-sang.jpg), [ảnh thắng](proof/phase-1/03-ket-qua-thang.jpg), [ảnh thua](proof/phase-1/04-ket-qua-thua.jpg), [ảnh tỏa sáng](proof/phase-1/05-toa-sang.jpg) và [JSONL mẫu](proof/phase-1/thap-den.jsonl).

## Nhật ký AI và đánh giá

- Dùng Codex để đọc bảy tài liệu, chuyển Test Contract thành các phép kiểm, xây game và chạy kiểm chứng. Người dùng cung cấp PRD qua `text.txt`, chọn làm tại thư mục hiện tại và xác nhận mã nhóm. Ước tính 30–45 nghìn token xử lý gồm đầu vào, mã, log và lượt rà soát. Đây là ước tính từ phiên làm việc.
- Dùng chung một mô phỏng để tránh lặp hai bộ luật. Lệnh `verify` chạy kiểm thử contract và lượt chơi qua scene. Các scenario nhỏ giới hạn thực thể để kiểm rõ từng hành vi.
- Godot phát hiện lỗi suy luận kiểu trong script mỹ thuật. Đã bổ sung kiểu và chạy lại bước kiểm tra cú pháp. Một ca kiểm thử đặt đom đóm lệch ở cả hai trục khi đo bán kính, dẫn tới kỳ vọng sai. Đã sửa tọa độ của ca nạp từng phần và giữ ca riêng kiểm tra biên chính xác.
- Bằng chứng được tạo trên Windows, Godot 4.4.1, OpenGL Compatibility và NVIDIA GeForce RTX 3050 Laptop GPU. `origin` trỏ tới repo của lớp. Phase này được làm cục bộ theo yêu cầu của người dùng.
