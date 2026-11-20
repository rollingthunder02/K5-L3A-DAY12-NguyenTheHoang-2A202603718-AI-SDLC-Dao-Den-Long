# Đảo Đèn Lồng

- Yêu cầu hiện hành nằm trong `phase 3.txt`, `phase 2.txt`, `text.txt` và `game.contract.json` (v1.2). Ticket mới ưu tiên khi thay luật cũ.
- Dùng Godot 4.4+, GDScript và chế độ Compatibility. `bash tools/game.sh build` kiểm tra script. `bash tools/game.sh play` mở game. `GODOT_BIN` cho phép chọn executable.
- `src/night.gd` là logic chung ở 60 tick/giây. `src/island_map.gd` định nghĩa địa hình và tọa độ chuẩn cho gameplay và hiển thị. `src/main.gd` điều phối input và màn hình. `src/headless.gd` ghi Test Contract JSONL.
- Giữ tick 0, cạnh nút và phân biệt `tick` với `sim_tick`. Dầu giữ số nguyên theo 1/60 và hao ở bước 2 cùng phần dầu bị hút. Xử lý đèn tắt trước lượt chơi và chỉ xét thắng sau mọi cập nhật ở tick bình minh.
- Chạy `bash tools/game.sh build` và `bash tools/game.sh verify` trước khi bàn giao. Lệnh chạy ca v1.2, hồi quy Phase 1–2 và `tests/campaign_flow.gd`. PowerShell có thể chạy `python -m unittest discover -s tests -p 'verify_phase*.py' -v` với `GODOT_BIN`.
- Lưu kết quả chạy thật có thể tái lập trong `docs/proof/`, ghi rõ môi trường và phần chưa kiểm chứng. Không sửa tay JSONL hoặc log kiểm thử.
