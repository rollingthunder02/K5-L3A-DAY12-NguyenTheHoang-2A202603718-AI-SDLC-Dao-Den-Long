# Đảo Đèn Lồng

- Yêu cầu hiện hành nằm trong `text.txt` và `game.contract.json`. Đọc ticket mới trước khi thay đổi hành vi của phase cũ.
- Dùng Godot 4.4+, GDScript và chế độ Compatibility. `bash tools/game.sh build` kiểm tra script. `bash tools/game.sh play` mở game. `GODOT_BIN` cho phép chọn executable.
- `src/night.gd` là logic chung ở 60 tick/giây. `src/main.gd` điều phối input và hiển thị. `src/headless.gd` ghi Test Contract JSONL. Bản đồ, mô hình và hiệu ứng chỉ đọc trạng thái gameplay.
- `game.contract.json` là nguồn hệ số gameplay. Giữ đúng ngữ nghĩa tick 0, tick sự kiện, quy tắc cạnh nút và đơn vị XZ.
- Chạy `bash tools/game.sh verify` trước khi bàn giao thay đổi. Lệnh chạy cả kiểm chứng JSONL và lượt chơi qua scene. Windows PowerShell có thể chạy `python tests/verify_phase1.py` với `GODOT_BIN` và chạy `res://tests/playthrough.gd` bằng Godot.
- Lưu kết quả chạy thật có thể tái lập trong `docs/proof/`, ghi rõ môi trường và phần chưa kiểm chứng. Không sửa tay JSONL hoặc log kiểm thử.
