# Đảo Đèn Lồng

- Yêu cầu hiện hành nằm trong `phase 2.txt`, `text.txt` và `game.contract.json` (v1.1). Ticket mới ưu tiên khi thay luật cũ.
- Dùng Godot 4.4+, GDScript và chế độ Compatibility. `bash tools/game.sh build` kiểm tra script. `bash tools/game.sh play` mở game. `GODOT_BIN` cho phép chọn executable.
- `src/night.gd` là logic chung ở 60 tick/giây. `src/island_map.gd` định nghĩa địa hình và tọa độ chuẩn cho gameplay và hiển thị. `src/main.gd` điều phối input và màn hình. `src/headless.gd` ghi Test Contract JSONL.
- Giữ tick 0, thứ tự bước của Ticket-02, cạnh nút và phân biệt `tick` với `sim_tick`. Lướt, choáng, đom đóm rơi, hồi bùa, gió và sinh thực thể theo `sim_tick`.
- Chạy `bash tools/game.sh build` và `bash tools/game.sh verify` trước khi bàn giao. Kiểm tra gồm các ca v1.1, hồi quy Phase 1 và `tests/campaign_flow.gd`. PowerShell có thể chạy `python -m unittest discover -s tests -p 'verify_phase*.py' -v` với `GODOT_BIN`. Kiểm FPS qua `tests/benchmark.gd` ở 1280×720.
- Lưu kết quả chạy thật có thể tái lập trong `docs/proof/`, ghi rõ môi trường và phần chưa kiểm chứng. Không sửa tay JSONL hoặc log kiểm thử.
