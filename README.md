# Day 12 — AI SDLC: Đảo Đèn Lồng

> **Cá nhân** (1 người / 1 MSSV) · Áp dụng SDLC cùng AI để xây một **game 3D** qua **4 phase**, từ yêu cầu ban đầu tới bản phát hành.
> **Lab board + trợ giảng:** **[Đảo Đèn Lồng Lab](https://claude.ai/artifact/Q1RYyv1dxjUczzCbd2ZnoW)**

---

## Chơi Đêm 1 — Đảo Bến

Gom đom đóm và thắp đủ năm Đèn Lồng Lớn trước bình minh. Mây có ba ngọn lửa. Khi Bóng Mực chạm vào Mây, một ngọn lửa tắt. Đèn đã thắp tạo vùng an toàn.

**macOS/Linux.** Cài Godot 4.4 trở lên và để `godot` hoặc `godot4` trên `PATH`. Script cũng nhận bản macOS đã cài ở `/Applications/Godot.app` hoặc đường dẫn đặt trong `GODOT_BIN`. Từ thư mục gốc, chạy hai lệnh sau. [Tải Godot](https://godotengine.org/download/)

```bash
bash tools/game.sh build
bash tools/game.sh play
```

**Windows.** Mở `project.godot` trong Godot Project Manager rồi nhấn **F5**. Từ PowerShell trên máy làm bài, có thể chạy `& 'D:\Godot_v4.4.1-stable_win64_console.exe' --path .`.

| Phím | Hành động |
|---|---|
| WASD hoặc phím mũi tên | Di chuyển theo góc nhìn camera |
| Chuột | Xoay camera |
| Space | Nhảy |
| E | Nạp đom đóm vào đèn chưa sáng gần nhất |
| Q | Tiêu 2 đom đóm để tỏa sáng, đẩy lùi và làm choáng Bóng Mực trong vùng ảnh hưởng |
| Esc | Tạm dừng và thả chuột. Nhấp vào game hoặc nhấn Esc để tiếp tục |
| R hoặc nút **Chơi lại** | Bắt đầu lại cùng bản đồ sau khi thắng hoặc thua |

**Điểm.** Nhặt đom đóm +10, thắp một đèn +120 và làm choáng một Bóng Mực +25. Khi thắng, cộng thêm 2 điểm mỗi giây nguyên còn lại và 75 điểm mỗi ngọn lửa còn lại.

### Chế độ headless và kiểm thử

Chạy từ thư mục gốc. Lệnh `verify` cần thêm Python 3.8 trở lên.

```bash
bash tools/game.sh headless --seed 42 --night 1 --scenario tests/scenarios/thap-den.json --inputs tests/scenarios/thap-den.inputs.json --ticks 20 --snapshot-every 1 --out phase1.jsonl
bash tools/game.sh verify
```

Trên Windows PowerShell, thay `bash tools/game.sh headless` bằng `& 'D:\Godot_v4.4.1-stable_win64_console.exe' --headless --path . --script res://src/headless.gd --`. Để chạy bộ kiểm chứng contract trên máy này, đặt `$env:GODOT_BIN = 'D:\Godot_v4.4.1-stable_win64_console.exe'` rồi chạy `python tests/verify_phase1.py`.

Test Contract dùng bước cố định 60 tick/giây. Các tương tác dùng khoảng cách mặt phẳng XZ. Game chặn ở mép đảo (`fall_enabled: false`). `dash` được đọc dưới dạng boolean nếu đầu vào gửi trường này. Phase 1 chưa có kỹ năng lao nhanh. Xem hệ số trong [game.contract.json](game.contract.json), [giả định và cách kiểm chứng](docs/phase-1.md) và [bằng chứng chạy thật](docs/proof/phase-1/).

### Sáng tạo của tôi

Bản đồ góc màn hình đánh dấu Mây, đom đóm, đèn và Bóng Mực để người chơi tự chọn đường đi trong sương. Vòng sáng trên mặt đất cho biết ranh giới an toàn quanh mỗi đèn đã thắp. Hai phần hiển thị đọc trạng thái của game. [Ảnh đèn đã sáng](docs/proof/phase-1/02-den-da-sang.jpg) · [Kết quả kiểm thử headless](docs/proof/phase-1/contract-tests.log)

---

## Tài liệu của lab

| File | Nội dung |
|---|---|
| [GUIDE.md](GUIDE.md) | Hướng dẫn làm lab: vòng làm việc mỗi phase, harness, kiểm chứng, token |
| [CHECKPOINTS.md](CHECKPOINTS.md) | Các mốc tự kiểm tra từ chuẩn bị đến nộp bài |
| [SUBMISSION.md](SUBMISSION.md) | Đặt tên repo, hạn nộp, tag, Release, video, checklist |
| [RULES.md](RULES.md) | Quy định: AI, trung thực về bằng chứng, bản quyền, bảo mật |
| [RUBRIC.md](RUBRIC.md) | Thang điểm chi tiết |

## Lab board

Yêu cầu dự án được phát hành tại **[Đảo Đèn Lồng Lab](https://claude.ai/artifact/Q1RYyv1dxjUczzCbd2ZnoW)**. Mỗi phase là một tab (tab chưa phát hành bị khóa), mỗi tab có trợ giảng AI riêng chỉ trả lời trong phạm vi phase đó. Trợ giảng cần đăng nhập claude.ai và dùng lượt Claude của bạn.

## Dự án

**Đảo Đèn Lồng**: game 3D góc nhìn thứ ba. Mây, người giữ đèn nhỏ tuổi, gom đom đóm để thắp lại các Đèn Lồng Lớn và né Bóng Mực trong sương đen.

- Không ràng buộc công nghệ; chạy được trên macOS hoặc Linux.
- Tuân theo **Test Contract** (chế độ headless) để được chấm tự động và so sánh với nhau.

| Phase | Bạn nhận | Nộp |
|---|---|---|
| 1 | **PRD-0** (mô tả tổng quát) + Test Contract | tag `phase-1` |
| 2 | **Ticket-02**, phát hành khi Phase 1 kết thúc | tag `phase-2` |
| 3 | **Ticket-03**, phát hành khi Phase 2 kết thúc | tag `phase-3` |
| 4 | **Ticket-04**, phát hành khi Phase 3 kết thúc | tag `phase-4` + Release `v1.0.0` |

Yêu cầu sẽ được bổ sung và có thể thay đổi giữa các phase, giống dự án thật.

### Lịch 4 giờ

Bài lab kéo dài **4 giờ**. Phase 1 và 2 khoảng **1 giờ**, Phase 3 khoảng **30 phút**, Phase 4 khoảng **1 giờ 30 phút**. Mỗi phase phát hành đúng mốc giờ. Phase mới xuất hiện trên lab board khi tới mốc.

| Mốc | Sự kiện | Hạn tag |
|---|---|---|
| 0h | Phát hành **Phase 1** (PRD-0), gồm cả phần chuẩn bị | `phase-1` trước mốc 1h |
| 1h | Phát hành **Phase 2** | `phase-2` trước mốc 2h |
| 2h | Phát hành **Phase 3** | `phase-3` trước mốc 2h30 |
| 2h30 | Phát hành **Phase 4** | `phase-4`, Release `v1.0.0` và video trước mốc 4h |
| 4h | Hết giờ lab, chốt bài | |

Hết giờ mỗi phase thì tag và chuyển sang phase tiếp theo, dù phase chưa hoàn hảo. Chỗ chưa xong ghi trung thực trong bằng chứng.

---

## Gợi ý SDLC (cách làm là của bạn)

Mỗi phase là một vòng nhỏ. Công cụ, thứ tự, định dạng tài liệu đều tự do; đây chỉ là gợi ý:

1. **Requirements:** biến yêu cầu thành tiêu chí nghiệm thu kiểm chứng được. Chỗ mơ hồ thì tự giả định và ghi lại.
2. **Plan:** nghĩ cách kiểm chứng **trước** khi để agent viết code.
3. **Build:** để agent viết, bạn điều phối và review.
4. **Verify:** chạy thật, kiểm tra hành vi thật. *Không có bằng chứng thì chưa xong*: "agent bảo chạy rồi" không phải bằng chứng.
5. **Evaluate:** cái gì đạt, AI sai ở đâu, harness (AGENTS.md, skill, hook) cần chỉnh gì.
6. **Release:** gắn tag.

## Ba điều cần nhớ

> Bạn được **tự do sáng tạo thêm** quanh phần lõi (nhân vật mới, kẻ địch mới, cơ chế nhỏ, câu chuyện, hiệu ứng, âm thanh…). Sáng tạo gọn và không phá yêu cầu được tính điểm trong hạng mục F của [RUBRIC](RUBRIC.md); ghi mục "Sáng tạo của tôi" trong README của bạn.

- **Game tốt là game đúng yêu cầu của khách hàng**, không phải game phức tạp hay đẹp nhất. Làm đúng và chứng minh được là đúng trước, trau chuốt sau.
- **Cân nhắc kỹ quota token của bạn.** Đốt nhiều token không làm bài tốt hơn. Ngữ cảnh gọn, kế hoạch rõ, kiểm chứng sớm thường vừa rẻ vừa đúng hơn chạy agent liên tục.
- **Kiểm chứng là phần quan trọng nhất.** Bằng chứng (test, output headless, ảnh, số đo) đáng giá hơn lời mô tả.

---

## Bàn giao cuối cùng

Một **repo GitHub cá nhân, public**, gồm:

1. **Toàn bộ mã nguồn** của game qua 4 phase, tag `phase-1` … `phase-4`, Release `v1.0.0`.
2. **Video demo `.mp4` dưới 5 phút** (đính kèm Release `v1.0.0` hoặc `docs/demo/demo.mp4`, link ở đầu README): chơi thử và cho thấy bằng chứng game chạy đúng.
3. **Bằng chứng kiểm chứng** của từng phase (định dạng tự chọn).
4. **Harness AI đã dùng** (AGENTS.md / CLAUDE.md, skills, hooks, plugins…), giữ nguyên trong repo và lịch sử git.
5. **Ghi chép ngắn:** spec/giả định mỗi phase, nhật ký dùng AI (gồm token/chi phí ước tính), retro.

Không commit API key, token hay `.env`. Gửi link repo theo hướng dẫn của Coach.

## Đánh giá (100 điểm)

| Hạng mục | Điểm |
|---|---|
| Test tự động ẩn (headless, gồm kiểm tra lại phase trước) | 30 |
| Kiểm chứng & bằng chứng của bạn | 20 |
| Quy trình SDLC & harness AI | 15 |
| Evaluation & retro (gồm cách bạn dùng token) | 10 |
| Hiệu năng & ổn định | 10 |
| Chất lượng sản phẩm (đúng yêu cầu, chơi được) | 10 |
| Video demo | 5 |

## Quy định

- Dùng AI thoải mái; không sao chép repo của người khác.
- Bằng chứng phải thật: test luôn đạt hay output sửa tay là vi phạm.
- Nhân vật, bối cảnh là bản gốc của lab; asset bên ngoài chỉ dùng loại CC0/CC-BY/MIT hoặc tự tạo, ghi nguồn trong `CREDITS.md`.
