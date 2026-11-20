# Bằng chứng Phase 2

Các kết quả trong thư mục này được ghi ở Contract v1.1. Lượt kiểm scene hiện hành đã được cập nhật cho luật bình minh của Phase 3. [Bằng chứng Phase 3](../phase-3/README.md)

- `build.log` và `verify.log` là đầu ra của `bash tools/game.sh build` và `bash tools/game.sh verify` trên Git Bash. Bộ kiểm chứng gồm 10 ca hồi quy Phase 1 và 12 ca Ticket‑02. Ca đo headless chạy đủ 21.600 tick, ghi snapshot mỗi 10 tick bằng cấu hình Đêm 3 có thực thể mặc định và bất tử đủ lâu để tới bình minh.
- `campaign.log` và các ảnh được ghi qua cửa sổ Godot 1280×720. Lượt chạy dùng phím thật qua hệ thống input của scene. Để kiểm luồng và điểm chiến dịch, mỗi đêm có một kịch bản được đặt gần đèn cuối. Phần thua dùng một đêm cận bình minh. Cài đặt được đổi qua hai thanh rồi tải lại trong scene mới. Có ảnh cảnh báo lá bay ở Đảo Chuông.
- `fps.log` đo từng bản đồ tại 1280×720 và tắt VSync. Mỗi đêm có 2 giây khởi động và 4 giây đo theo đồng hồ thực, với đom đóm, số Bóng Mực tối đa của đêm đó và hai Gió Lạc ở Đêm 2/3. Máy chạy Windows, Godot 4.4.1, OpenGL Compatibility, NVIDIA GeForce RTX 3050 Laptop GPU.
- `cau.jsonl` được ghi ở Đảo Cau với `tests/scenarios/phase2-cau.json`, `tests/scenarios/phase2-cau.inputs.json`, seed 42, 144 tick và chu kỳ snapshot 12. Lướt ở tick 1, tạm dừng ở tick 6, tiếp tục ở tick 26, nhặt Bùa Gió ở tick 44 và lướt lại ở tick 52. Hai lần xuất cho SHA‑256 giống nhau `07ffa026c071bb124d5f41b5c94dd5e3a5cdfde802195771d48be37c0566dd40`.

## Chạy lại phần đồ họa

Từ thư mục gốc, tạo thư mục ảnh đầu ra trước khi gọi Godot. `--fixed-fps 60` chỉ dùng khi chụp lượt kiểm, còn benchmark chạy theo thời gian thực.

```bash
mkdir -p .godot/p2-proof
godot --path . --audio-driver Dummy --resolution 1280x720 --disable-vsync --fixed-fps 60 --script res://tests/campaign_flow.gd -- .godot/p2-proof
godot --path . --audio-driver Dummy --resolution 1280x720 --disable-vsync --script res://tests/benchmark.gd
```

Trên Windows, dùng trực tiếp đường dẫn `Godot_v4.4.1-stable_win64_console.exe`. Các lượt đo dùng trình điều khiển âm thanh `Dummy`. Bằng chứng âm thanh của lượt kiểm xác nhận dữ liệu nhạc lặp và danh sách hiệu ứng.
