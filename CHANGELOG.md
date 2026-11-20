# Changelog

## Phase 3 · Contract v1.2

### Thay đổi không tương thích

- Thắp đủ đèn trong đêm không kết thúc màn. Chỉ kiểm ngưỡng đèn sáng ở bình minh. `game_over.reason` dùng `dawn_survived` khi thắng. `all_lit` đã được bỏ. Ba đêm dài 240, 270 và 300 giây.
- Đèn sáng có dầu và nhận thêm đom đóm qua sự kiện `refuel`. Đèn cạn dầu phát `lantern_out`, xóa tiến độ nạp và có thể thắp lại với giá 5 đom đóm. `lantern_lit` có trường bắt buộc `relight`.
- Đèn dưới 30 dầu mất vùng an toàn. Bóng Mực có trạng thái `drain` và sự kiện định kỳ `fuel_drain`. Hết choáng chuyển về `wander` trước lần phát hiện tiếp theo.
- `score.per_mote` đổi từ 10 thành 5. Thưởng thời gian `per_second_left` được bỏ. Điểm thêm gồm thắp lại, tỏa sáng trúng Bóng Mực đang hút dầu và thưởng mỗi đèn giữ sáng ở bình minh.
- Snapshot thêm `player.capacity` và `lanterns[].fuel`, `ever_lit`, `relit_count`. Sức chứa tăng từ 10 tới 20 theo các lần thắp thành công. Đèn đặt sẵn trong scenario không tăng sức chứa.

### Bổ sung

- Scenario hỗ trợ `player.successful_lights`, `lanterns[].fuel`, `lanterns[].ever_lit` và `shades[].target_lantern_id`.
- Cài đặt lưu tùy chọn **Bảng màu dễ phân biệt**, thêm thanh dầu trên đèn, vết rách và chiều cao phân biệt đèn đã tắt.
