# Analysis — Câu hỏi kinh doanh và khối dữ liệu

Bốn câu hỏi, mỗi câu được viết thành một truy vấn trên `v_olap` rồi cube hoá để có thêm các cấp tổng hợp. Sáu khối dữ liệu phục vụ bốn câu hỏi này.

---

## 1. Câu hỏi kinh doanh

### CH1 — "Doanh thu quý vừa rồi tăng hay giảm so với quý trước, và trong quý thì tháng nào kéo kết quả xuống?"

**Người dùng.** Ban điều hành, trong họp tổng kết quý.

**Ý nghĩa.** Câu hỏi có hai tầng: một con số để báo cáo, và một nguyên nhân để xử lý. Biết quý giảm mà không biết tháng nào gây ra thì không hành động được, nên hệ thống phải cho đi xuống cấp tháng ngay trong lúc họp chứ không đợi viết truy vấn mới.

**Toán tử.** Roll-up (merge) để gộp tháng lên quý lên năm · drill-down để mở quý ra từng tháng · slice để xem riêng một năm.

### CH2 — "Ngân sách khuyến mãi quý tới nên dồn vào vùng nào và ngành hàng nào, và lựa chọn đó có đổi theo mùa không?"

**Người dùng.** Marketing, khi lập kế hoạch ngân sách.

**Ý nghĩa.** Quyết định phân bổ tiền nên người lập kế hoạch phải xem được mọi tổ hợp của ba chiều quý, vùng, ngành hàng — tổng theo vùng để chia ngân sách lớn, tổng theo ngành để chọn danh mục, chi tiết từng ô để chọn chiến dịch. Kết quả trả lời trực tiếp: doanh thu tập trung 78,3% ở Southeast và 16,8% ở South, nên dàn đều năm vùng là sai.

**Toán tử.** Cube để sinh đủ tám cuboid · pivot để xoay vùng thành cột · slice để chốt một quý · dice để lọc đồng thời vùng, ngành và quý.

### CH3 — "Khách ở vùng nào đang phàn nàn nhiều nhất, và trong vùng đó ngành hàng nào là nguyên nhân?"

**Người dùng.** Quản lý ngành hàng, khi xử lý khiếu nại.

**Ý nghĩa.** Điểm đánh giá trung bình toàn sàn là 4,16, đủ cao để che các điểm nóng. Câu hỏi buộc phải đi từ mức vùng xuống mức ngành hàng rồi quay lại so sánh, vì một vùng kém thường do vài ngành kéo xuống chứ không phải kém đều.

**Toán tử.** Drill-down từ vùng khách xuống ngành hàng · roll-up quay lại cấp vùng để so sánh.

### CH4 — "Ngành hàng nào đang phụ thuộc vào quá ít người bán, và sự phụ thuộc đó có làm khách hàng chịu thiệt không?"

**Người dùng.** Nhóm tuyển người bán, khi lập kế hoạch tuyển.

**Ý nghĩa.** Vế đầu đo rủi ro nguồn cung bằng HHI; vế sau mới là lý do phải tuyển: nếu ngành tập trung cao mà khách vẫn hài lòng thì không cần can thiệp. Hai vế nằm ở hai khối khác nhau nên phải nối lại. Kết quả: ngành HHI trên 2.500 có điểm 3,91 và trễ 7,8%, ngành HHI dưới 1.500 có điểm 4,20 và trễ 6,1%.

**Toán tử.** Join để nối `cube_category_seller` với `cube_quality` qua `category_en` · roll-up để lấy cấp ngành hàng đã gộp hết chiều vùng khách.

---

## 2. Khối dữ liệu được sử dụng

| Khối | Dựng bằng | Phục vụ | Cấp dữ liệu dùng tới |
|---|---|---|---|
| `cube_time` | `ROLLUP` | CH1 | `muc = 'Tổng'` cho 4 ô chỉ số · `muc = 'Quý'` cho cột doanh thu · `muc = 'Tháng'` để drill-down |
| `cube_qrc` | `CUBE` | CH2 | `gid = 1` cho ma trận quý × vùng · `gid = 6` cho xếp hạng ngành hàng |
| `cube_quality` | `GROUPING SETS` | CH3, CH4 | Cấp vùng khách cho biểu đồ giao trễ · cấp ngành hàng cho biểu đồ điểm thấp và cho phép join của CH4 |
| `cube_category_seller` | Xếp hạng theo HHI | CH4 | Cấp ngành hàng, lọc `du_du_lieu` tức từ 20 người bán trở lên |
| `cube_seller_abc` | `GROUPING SETS` | Bổ trợ CH4 | `g_region = 1` và `g_abc = 0` cho ba hạng A, B, C |
| `cube_status` | `GROUPING SETS` | Kiểm tra | Cơ cấu trạng thái đơn, chạy trên `v_olap_all` |

### Cột `gid` của `cube_qrc`

`gid = GROUPING(quarter_key)*4 + GROUPING(seller_region)*2 + GROUPING(category_en)`. Bit nào bằng 1 thì chiều đó đã bị gộp. Nhờ `gid`, một bảng phục vụ nhiều biểu đồ; khi vẽ phải lọc theo `gid` để không trộn dòng tổng vào dòng chi tiết.

| gid | Chiều còn lại | Số ô |
|---|---|---|
| 0 | Quý × Vùng × Ngành | 1.132 |
| 1 | Quý × Vùng | 39 |
| 2 | Quý × Ngành | 500 |
| 3 | Quý | 9 |
| 4 | Vùng × Ngành | 210 |
| 5 | Vùng | 5 |
| 6 | Ngành | 72 |
| 7 | Tổng toàn sàn | 1 |
