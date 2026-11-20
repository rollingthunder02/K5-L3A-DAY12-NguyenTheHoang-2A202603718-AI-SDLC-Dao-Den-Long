# Bằng chứng Phase 3

- `build.log` và `verify.log` ghi lệnh `bash tools/game.sh build` và `bash tools/game.sh verify` trên Git Bash. Suite có 30 ca, gồm 22 ca hồi quy và 8 ca Ticket‑03.
- `campaign.log` ghi lượt kiểm qua cửa sổ ở 1280×720. Mỗi đêm dùng kịch bản ngắn đặt Mây gần đèn cuối, nhấn E, kiểm đêm vẫn tiếp tục, rồi chờ bình minh. Lượt chạy cũng đổi bảng màu bằng giao diện, mở scene mới để kiểm cài đặt, kiểm cảnh báo trắng và đo hai nửa chu kỳ nhấp nháy.
- `fps.log` đo 4 giây mỗi bản đồ ở 1280×720, VSync tắt. Ba đêm đạt lần lượt 439,27, 422,74 và 350,13 FPS trung bình trên NVIDIA GeForce RTX 3050 Laptop GPU. Lượt headless Đêm 3 đủ 18.000 tick và ghi snapshot mất 6,73 giây trong `verify.log`.
- `oil.jsonl` là kết quả lệnh mẫu ở README gốc. Đèn L1 tắt rồi được thắp lại ở tick 1, L2 được châm ở tick 17, S1 hút L4 ở tick 60, 120 và 180, kết thúc `dawn_survived` với 713 điểm. Hai lượt có cùng SHA‑256 `017b89b00f89f12bb58fbe7935c9c263524b99381b28e1ee8d607c0c2dde375c`.
- Ảnh [cài đặt](02-cai-dat.jpg), [thanh dầu đang hiện](11-den-dau.jpg), [nửa chu kỳ đèn mờ](12-den-nhap-nhay.jpg) và [màn Bình Minh](08-binh-minh.jpg) được chụp từ Godot 4.4.1 trên Windows. Nhạc và các thiết lập âm thanh trong lượt test dùng trình điều khiển `Dummy`.

## Tạo lại ảnh và log cửa sổ

```bash
mkdir -p .godot/p3-proof
godot --path . --audio-driver Dummy --resolution 1280x720 --disable-vsync --fixed-fps 60 --script res://tests/campaign_flow.gd -- .godot/p3-proof
```

Trên Windows dùng trực tiếp executable Godot đã cài. Hướng dẫn lệnh headless nằm trong [README gốc](../../../README.md).
