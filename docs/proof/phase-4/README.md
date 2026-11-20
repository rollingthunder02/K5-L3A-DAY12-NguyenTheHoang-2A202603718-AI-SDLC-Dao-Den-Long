# Kiểm chứng Phase 4

Các lệnh chạy trong thư mục gốc với Godot 4.4.1 stable official. Bộ kiểm hồi quy chạy trên Windows 11 build 26200. Benchmark dùng OpenGL Compatibility trên NVIDIA GeForce RTX 3050 Laptop GPU, cửa sổ 1280×720 và tắt VSync.

| Phép kiểm | Kết quả trên máy làm bài |
|---|---|
| Build và verify | Build thành công, 30 ca Python đạt và kịch bản campaign đạt |
| Benchmark · seed 42 · 30 giây sau khởi động | 9.685 khung hình, trung bình 322,85 FPS, 1% thấp 116,31 FPS, p95 7,415 ms, tải 2.265 ms, đỉnh RSS 234,38 MB |
| Soak · seed 7 · 10 đêm | Một tiến trình, 0 crash, RSS 80,85 → 80,96 MB, 6,31 giây |

[Log build](build.log) · [Log verify](verify.log) · [Log campaign có cửa sổ](campaign.log) · [JSON benchmark](../../../bench.json) · [JSON soak](../../../soak.json)

```bash
bash tools/game.sh build
bash tools/game.sh verify
bash tools/game.sh bench --seed 42 --duration 30 --out bench.json
bash tools/game.sh soak --seed 7 --nights 10 --out soak.json
bash tools/game.sh headless --seed 42 --night 1 --scenario tests/scenarios/phase3-oil.json --inputs tests/scenarios/phase3-oil.inputs.json --ticks 180 --snapshot-every 30 --out phase3.jsonl
```

Ca headless mẫu kết thúc ở tick 180 với 713 điểm. Campaign kiểm tra lưu và khôi phục cài đặt, từ chối phím trùng, khôi phục phím mặc định, ba đêm thắng, màn thua và thứ tự hòa điểm trong bảng xếp hạng. [JSONL headless](../phase-3/oil.jsonl) · [Ảnh bảng xếp hạng](14-bang-xep-hang.jpg) · [Ảnh màn chơi](11-den-dau.jpg)

Executable độc lập được kiểm khởi động headless và xuất bảng xếp hạng trống trên Windows và Ubuntu WSL. Giao diện gameplay và menu được kiểm với cửa sổ trên Windows. Video demo ghi ở 1280×720, dài khoảng 20 giây.

Kết quả hiệu năng phụ thuộc vào cấu hình và tải của máy khi chạy. Máy chấm và các test ẩn do giảng viên quản lý chưa được kiểm trực tiếp.
