# Phase 3 — Ticket‑03 «Đèn cạn dầu»

## ADR — Trạng thái đèn và chiến thắng ở bình minh

**Bối cảnh.** Phase 2 lưu đèn bằng `lit` và tiến độ nạp, kết thúc đêm ngay khi đèn cuối sáng. Ticket‑03 yêu cầu đèn có thể tắt trong đêm và số đèn sáng chỉ quyết định chiến thắng ở bình minh.

**Quyết định.** Giữ `lit` và tiến độ nạp, thêm lượng dầu nguyên theo đơn vị 1/60, `ever_lit` và `relit_count`. Mỗi bước tiêu 1 đơn vị nhỏ khi đèn sáng và thêm 5 đơn vị nhỏ cho từng Bóng Mực đang hút. Áp dụng tổng hao hụt trước khi xử lý di chuyển, nhặt hoặc tương tác. Nếu dầu về 0, đèn tắt ngay, xóa tiến độ và giữ `ever_lit` để giảm giá thắp lại.

Chỉ kết thúc ngay khi Mây hết Ngọn Lửa. Ở bình minh, dùng số đèn sáng sau mọi cập nhật của tick để kiểm ngưỡng `ceil(60% × tổng đèn)`. Chỉ khi thắng mới cộng thưởng đèn và lửa. Mô phỏng headless và scene Godot cùng dùng `src/night.gd`.

**Hệ quả.** Dầu đúng 30 giữ vùng an toàn. Snapshot làm tròn một chữ số có thể hiện `30.0` sau khi mức thật đã dưới 30. Điểm bình minh lấy phần nguyên từ mức dầu thật. Nhấn E sau bước hao dầu sẽ tính một đom đóm ngay cả khi lượng dầu chỉ thiếu 1/60 và HUD còn hiện 100 khi làm tròn. Tạm dừng đóng băng dầu cùng các bộ đếm khác.

## Quy ước triển khai

- Khi Bóng Mực vừa chuyển sang `drain`, lần hút dầu đầu tiên xảy ra ở bước 2 của tick kế tiếp. `fuel_drain` ghi theo mỗi 60 tick hút liên tục của từng con, dùng lượng dầu còn lại sau khi cộng dồn các con cùng hút. Nếu nhận đủ dầu để khôi phục vùng an toàn, kẻ địch rời `drain` ở bước cập nhật vùng an toàn, trước Tỏa Sáng. Việc Mây tới gần 6 m được kiểm ở bước cập nhật chuyển động Bóng Mực.
- Phát hiện Mây trong 12 m và bỏ đuổi ngoài 18 m vẫn theo Ticket‑02. Bóng Mực đã ở trạng thái `chase` tiếp tục đuổi Mây. Khi `wander` không chọn được đèn yếu, nó tìm đèn tắt gần nhất. Chỉ khi không có hai loại đèn đó mới dùng điểm đi dạo.
- Đèn đặt `lit: true` mặc định 100 dầu và `ever_lit: true`. Đèn đặt sẵn không cộng điểm, sức chứa hoặc số lần thắp lại. `successful_lights` do scenario khai chỉ thay sức chứa đầu vào.
- Giữ phạm vi E theo XZ và ưu tiên ID thấp hơn khi hai đèn cùng khoảng cách. Thanh dầu, giấy rách và bảng màu nằm ở lớp hiển thị, nên trạng thái cài đặt không ảnh hưởng JSONL.

## Kiểm chứng và hồi quy

| Yêu cầu | Bằng chứng |
|---|---|
| Hao dầu đúng tick, nhấn E chọn đèn đủ điều kiện, châm dầu làm tròn lên, thắp lại giá 5 và tăng sức chứa | `tests/verify_phase3.py` và `oil.jsonl` |
| Biên 30 dùng dầu thật, hút dầu cộng dồn, trạng thái và điểm Tỏa Sáng, khôi phục vùng an toàn đẩy Bóng Mực trong 30 tick | `tests/verify_phase3.py` |
| Thắng ở 3/5, 4/6, 5/7 đèn tại bình minh, gồm tắt và thắp lại đúng tick cuối, hết lửa luôn thua trước | `tests/verify_phase3.py`, `tests/verify_phase2.py` và lượt scene có kịch bản ngắn |
| Thanh dầu nhấp nháy theo chu kỳ một giây, đèn tắt thấp hơn 20% và có giấy rách, ambient giảm sau tắt | `tests/campaign_flow.gd`, ảnh và log cửa sổ Godot |
| Bảng màu lưu qua lần mở, Bóng Mực xanh lam và cảnh báo trắng có ⚠, HUD hiện đang mang / sức chứa | `tests/campaign_flow.gd`, ảnh cài đặt và ảnh HUD |
| Các hành vi Phase 1–2 còn hiệu lực | Lệnh `bash tools/game.sh verify` chạy toàn bộ test đang dùng |

Các test cũ đã được cập nhật: lúc đèn cuối sáng vẫn `playing`, thắng đổi lý do và điểm sang bình minh, khi hết choáng chuyển về `wander`, thời lượng/contract theo v1.2. Ca đo Đêm 3 dùng 18.000 tick theo thời lượng 300 giây. Ảnh và log của v1.0/v1.1 được giữ trong thư mục phase tương ứng.

## Nhật ký AI

- Codex dùng một mô phỏng cho hai chế độ, lập ca kiểm theo mốc tick và giữ bằng chứng tách theo phase. Ước tính 32–50 nghìn token xử lý gồm đọc mã, chỉnh sửa, log và rà soát. Số này là ước tính từ phiên làm việc.
- Kiểm chứng trên Windows bằng Godot 4.4.1. Các test ẩn của giảng viên và bản chạy trên macOS/Linux chưa được kiểm chứng trong phiên. [Bằng chứng Phase 3](proof/phase-3/README.md)
