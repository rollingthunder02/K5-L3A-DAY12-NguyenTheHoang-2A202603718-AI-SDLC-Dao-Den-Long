# Phase 2 — Ticket‑02 «Ba hòn đảo»

## Tiêu chí nghiệm thu

| Yêu cầu | Cách kiểm chứng |
|---|---|
| Lướt 14 m/s trong 12 tick, hồi 90 tick, giữ độ cao khi lướt trên không và vẫn có thể bị đánh | `test_dash_duration_direction_cooldown_and_air_height` và phím Shift qua scene |
| 20 đom đóm trên các điểm chuẩn, sinh thêm mỗi 240 tick; các đèn nhớ lượng đã nạp; Bóng Mực sinh đúng lịch và số tối đa | `test_nights_maps_and_initial_stock`, `test_spawn_timing_caps_and_seeded_ids`, các ca nhặt/nạp hồi quy |
| Pulse khóa mục tiêu 3D, đẩy trong 15 tick, choáng 120 tick; vùng an toàn chặn và đẩy Bóng Mực ra ngoài trong 30 tick | `test_pulse_range_push_duration_cost_and_cooldown`, `test_safe_zone_eviction_does_not_damage_and_knockback_stops_at_edge` |
| Va chạm giảm lửa, rơi đom đóm nhặt lại được, bất tử 90 tick; rơi khỏi đảo mất toàn bộ và hồi sinh sau 60 tick nếu còn lửa | `test_hit_drop_invulnerability_and_early_loss`, `test_drifters_steal_first_pulse_recovers_and_ttl_expires`, `test_fall_bypasses_invulnerability_and_waits_to_respawn` |
| Đi qua cầu tre hoặc nhảy sang đảo kia ở Đêm 2; đi đúng dốc và bục nhảy ở Đêm 3; gió đẩy trong 5 giây mỗi 30 giây, báo trước bằng lá và âm thanh | `test_bridge_and_jump_pad_between_the_islands`, `test_terrace_ramp_wall_tower_and_high_pad`, `test_wind_runs_exactly_300_ticks_and_can_be_disabled`; cảnh báo gọi hiệu ứng tại tick thứ 1680 trong mỗi chu kỳ 1800 tick |
| Gió Lạc săn khi Mây mang ít nhất 5 đom đóm, cướp trước Bóng Mực, không giảm lửa, bỏ chạy và có thể bị ép thả lại đom đóm | `test_drifters_steal_first_pulse_recovers_and_ttl_expires` và lịch sinh trong `test_spawn_timing_caps_and_seeded_ids` |
| Bùa Gió tăng chạy lên 7,2 m/s và bỏ hồi chiêu Lướt trong 600 tick, sinh lại sau 2700 tick | `test_charm_duration_dash_override_and_respawn` và kịch bản `phase2-cau.json` |
| Menu → giới thiệu của Ông Đăng → chơi → kết quả → đêm sau; Bình Minh cộng điểm ba đêm thắng; thua có thể chơi lại đêm đó | `tests/campaign_flow.gd` dùng nút của scene và kịch bản có đèn cuối để kiểm chứng cả ba lần chuyển đêm, kết quả và chơi lại |
| Esc/P dừng mô phỏng; menu có Tiếp tục, Chơi lại Đêm, Cài đặt và Về menu | `test_pause_freezes_time_cooldowns_spawn_ttl_and_movement`, `tests/campaign_flow.gd` và ảnh menu tạm dừng |
| Âm lượng và độ nhạy tự khôi phục khi mở game lại | `tests/campaign_flow.gd` thay giá trị hai thanh, kiểm tệp và mở lại scene |
| Nhạc nền lặp và các hiệu ứng theo sự kiện, kể cả đếm ngược 10 giây và gió sắp đến | Lượt kiểm scene kiểm dữ liệu WAV lặp. `src/night_audio.gd` định nghĩa hiệu ứng và `src/main.gd` phát khi có sự kiện hoặc mốc đếm giờ |
| HUD đúng vị trí, sức chứa 10 ô, đồng hồ đỏ nhấp nháy ở 30 giây cuối, hồi chiêu và mũi tên đèn ngoài khung hình | `tests/campaign_flow.gd` kiểm thanh 10 ô, dòng nhắc E, màu cảnh báo và ảnh cửa sổ thật của ba đêm |
| Màu nền, vật liệu và UI theo bảng màu; ambient bằng `0.15 + 0.55 × tỉ lệ đèn sáng` | Màu vật liệu và ambient được kiểm qua scene. Các ảnh thể hiện vật liệu dưới ánh sáng kết xuất |
| Contract v1.1, hồi quy Phase 1, 21.600 tick dưới 30 giây và ≥30 FPS tại 1280×720 | `bash tools/game.sh verify`, `tests/benchmark.gd` và các log lưu trong [bằng chứng](proof/phase-2/README.md) |

## Giả định và luật thay đổi

- Giữ cách đo XZ của Phase 1 cho nạp đèn, phát hiện, bỏ đuổi và vùng an toàn. Nhặt và hit áp dụng thêm chênh cao 1,5 m. Pulse dùng khoảng cách 3D với tâm cao hơn chân Mây 0,8 m. Cả ba đêm dùng điểm xuất phát gốc (0,0,0). Đất ở dưới đĩa tầng 2 của Đảo Chuông có thể đi qua.
- Bóng Mực mới ở `spawning` trong 30 tick. Khi đánh trúng, Bóng Mực thực hiện `recoil` lùi 2 m trong 60 tick nếu đường trống. Khi thắp đèn, Bóng Mực trong vùng được đẩy dần ra mép. Bóng Mực đang bị đẩy ra không thể gây sát thương.
- Đêm 2 và Đêm 3 giữ đợt đầu hai Bóng Mực ở tick 300 và dùng khoảng cách sinh 420/360 tick. Gió Lạc dùng điểm sương trên danh sách điểm sinh của đảo và không cướp trong tick vừa sinh.
- Đom đóm thường có `ttl_s: null`. Trần 30 chặn sinh đom đóm nền khi số đang có đạt trần. Đom đóm bắt buộc rơi do hit hoặc Gió Lạc vẫn xuất hiện đầy đủ. Điểm của `score.per_mote` trong v1.1 tính trên mỗi đom đóm nạp vào đèn.
- Headless xuất snapshot tick 0 rồi `night_start`. Khi nhấn bỏ tạm dừng, tick đó thực hiện lại một bước gameplay. `--night` chạy một đêm. Cộng điểm ba đêm nằm trong luồng chiến dịch.
- Danh sách scenario `motes`, `shades`, `drifters` thay thế mặc định. Có thể bật cờ ngẫu nhiên tương ứng để tiếp tục lịch sinh. `charms` có thể khai `id`, `pos`, `available`, `respawn_ticks`. `shades` và `drifters` hỗ trợ `state_ticks_left`. Mote scenario nhận vị trí kiểu mảng của v1.0 hoặc object có `pos`, `kind` và `ttl_ticks`.
- Các phép kiểm Phase 1 giữ nội dung cần hồi quy, cập nhật kỳ vọng vận tốc, số điểm và các luật bị thay. Script chơi cũ đã lưu cùng bằng chứng v1.0. Lượt kiểm scene mới bao phủ luồng ba đêm bằng kịch bản có sẵn tiến độ để lặp lại nhanh.

## Nhật ký AI

- Dùng Codex đọc Ticket‑02, triển khai theo logic mô phỏng chung, chia kịch bản kiểm theo mốc tick, xác minh bằng cả Windows Godot và Git Bash. Ước tính 55–75 nghìn token xử lý cả đầu vào, mã, log và rà soát, chưa có đồng hồ chi phí chi tiết trong phiên.
- Lượt kiểm đầu phát hiện các phép thử vẫn so toàn bộ snapshot vận tốc cũ và bỏ qua việc cầu tre có Bùa Gió. Đã tách kiểm cầu khỏi kiểm bùa, đồng thời dùng dung sai 1 mm cho tọa độ đã làm tròn. Lượt thử đồ họa phát hiện camera vướng tháp tại tầng cao. Đã bổ sung chặn camera và góc nhìn tổng quan ở Bình Minh.
- Kết quả được lưu cục bộ. macOS/Linux và các test ẩn của giảng viên chưa được chạy trong phiên này.
