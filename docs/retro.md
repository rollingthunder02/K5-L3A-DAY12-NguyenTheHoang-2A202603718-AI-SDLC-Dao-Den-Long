# Retro — Đảo Đèn Lồng

## Bốn mốc phát triển

| Phase | Điều đã kiểm được | Điều thay đổi cách làm |
|---|---|---|
| 1 | Màn Đảo Bến qua lượt thắng, thua, chơi lại. Mười ca headless và JSONL tái lập đúng từng byte. | Mô phỏng dùng chung ngay từ đầu. Kịch bản nhỏ cho thấy rõ thứ tự tick, cạnh nút và giới hạn XZ. |
| 2 | Ba đêm, cầu, bục, gió, bùa, Gió Lạc. 22 ca kiểm thử và 21.600 tick chạy trong khoảng 5,17 giây trên máy làm bài. | Bản đồ chuẩn trở thành dữ liệu dùng chung. Kịch bản mở màn với tiến độ có sẵn rút ngắn việc kiểm menu và chuyển đêm. |
| 3 | 30 ca kiểm thử, gồm phạm vi an toàn ở đúng 30 dầu và tranh chấp ở tick bình minh. Một đêm đầy đủ chạy khoảng 6,73 giây. | Dầu lưu theo đơn vị nguyên. Các khẳng định về thắng ngay và điểm thời gian trong test cũ được cập nhật có lý do. |
| 4 | Có benchmark, soak, bảng xếp hạng, cài đặt tiếp cận và bản đóng gói. Kết quả máy làm bài nằm trong `bench.json` và `soak.json`. | Đo thời gian khung hình và RSS tiến trình thực. Kiểm con đường xuất bản bằng gói đã export và một bản checkout sạch. |

## AI đã giúp và đã sai ở đâu

Codex hữu ích nhất khi biến mỗi luật thành đầu vào và đầu ra quan sát được. Quy tắc đầu tiên là kiểm JSONL ở đúng tick trước khi trau chuốt màn hình. Lệnh verify dùng lại các kiểm tra hành vi và lượt chạy scene, nên việc thay luật dầu không cần viết lại input hay mỹ thuật. Dữ liệu bản đồ dùng chung cũng tránh lệch giữa hai chế độ.

Ở Phase 1, một ca nạp từng phần đặt đom đóm lệch trên cả hai trục dù kỳ vọng nó ở biên bán kính. Tách ca đó khỏi phép thử đúng biên thì nguyên nhân rõ ngay. Sang Phase 2, phép đo đi qua cầu ban đầu bị Bùa Gió làm thay đổi tốc độ. Một kịch bản cầu không có bùa và một kịch bản bùa riêng cho kết quả dễ giải thích. Ảnh Phase 2 còn cho thấy camera lọt vào tháp, dẫn đến kiểm va chạm camera và góc nhìn Bình Minh.

Ở Phase 3, số dầu hiển thị 30,0 có thể đã xuống dưới ngưỡng 30. Kiểm thử dùng hai trạng thái có cùng số hiển thị nhưng vùng an toàn khác nhau. Biểu tượng cảnh báo ban đầu lấy từ phông emoji nên hiện vàng dù chữ đặt trắng. Ảnh chụp phát hiện điều đó, và biểu tượng được chuyển thành hình vẽ trắng. Ở Phase 4, mẫu RSS đầu đo nhầm tệp launcher Windows khoảng 5 MB. So với cấu trúc hai tiến trình, số quá thấp buộc đổi sang đo executable Godot thực.

## Harness và chi phí

`AGENTS.md` hữu ích nhất để giữ giới hạn phase và lệnh kiểm chuẩn. `tools/game.sh verify` và các scenario có thể chạy lại giúp phát hiện lỗi sớm hơn kiểm một lượt chơi bằng mắt. Ảnh chỉ dùng cho giao diện và đồ họa, còn số điểm và tick được đối chiếu từ dữ liệu.

Ước tính tổng cộng khoảng 147–225 nghìn token xử lý, gồm 30–45 nghìn ở Phase 1, 55–75 nghìn ở Phase 2, 32–50 nghìn ở Phase 3 và 30–55 nghìn ở Phase 4. Đây là khoảng ước tính gồm trao đổi, mã và log. Phiên làm việc không có số tiền tính phí để đối chiếu. Dùng một mô phỏng, tái dùng ca hồi quy và lấy đoạn log theo lỗi giúp hạn chế đọc lại cả dự án.

Nếu làm lại, mình sẽ lưu commit cuối từng phase ngay và thử quy trình đóng gói từ đầu. Hai lần khôi phục bản cũ mất thời gian dù các bằng chứng vẫn còn. Mình cũng sẽ thêm kiểm tra một lượt chơi scene ngắn ngay khi có menu, để phát hiện sớm lỗi focus và thay đổi phím.
