# Bằng chứng Phase 1

- `contract-tests.log` ghi kết quả mười ca kiểm thử tự động của `tests/verify_phase1.py`.
- `verify.log` ghi kết quả `bash tools/game.sh verify` chạy qua Git Bash trên Windows.
- `thap-den.jsonl` được tạo bằng lệnh mẫu trong README gốc. Mây nhặt một đom đóm, nạp và thắp L1 ở tick 1, kết thúc với 373 điểm. Hai lần chạy riêng và một lần chạy qua Git Bash cho cùng SHA‑256 `51ca5b6676c5713e182b3dbc6cdedec8823fec23635b6f7b94c716a4b65f63c8`.
- `playthrough.log` và năm ảnh được tạo trong một lượt chạy `tests/playthrough.gd` với cửa sổ thật. Script đưa thao tác qua đầu vào của scene, thắp năm đèn, chơi lại, dùng Q lên một Bóng Mực đang rượt đuổi, đứng yên đến khi thua và chơi lại bằng R.

## Chạy lại lượt chụp ảnh

Từ thư mục gốc, tạo thư mục đầu ra rồi truyền đường dẫn đó sau `--`. Lệnh chạy giao diện cần GPU. Bỏ phần đường dẫn và thêm `--headless` khi chỉ cần kiểm tra hành vi.

```bash
mkdir -p .godot/proof
godot --path . --audio-driver Dummy --disable-vsync --fixed-fps 60 --script res://tests/playthrough.gd -- .godot/proof
```

Máy ghi bằng chứng dùng Windows và `Godot_v4.4.1-stable_win64_console.exe`. Các ca kiểm thử dùng renderer Compatibility khi có giao diện.
