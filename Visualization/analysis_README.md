# Business use case và trực quan hoá

8 use case trả lời các tình huống phân tích trong kinh doanh khác nhau của doanh nghiệp gom thành 3 dashboard Tableau nối trực tiếp tới BigQuery. Script: `sql/`.

Tiêu chí chọn: câu trả lời phải dẫn tới một việc sàn làm được để tăng GMV hoặc giảm rò rỉ.

| Mã | Use case | Người dùng | Cube | Dashboard |
|---|---|---|---|---|
| UC1 | Lập kế hoạch theo mùa vụ | Ban điều hành, kế hoạch và tài chính | `cube_time` | 1 |
| UC2 | Phân bổ nguồn lực theo vùng và ngành | Marketing tăng trưởng, phát triển ngành hàng | `cube_qrc` | 1 |
| UC3 | Ưu tiên đầu tư vận chuyển theo tuyến | Vận hành giao hàng | `cube_route` | 2 |
| UC4 | Kiểm soát chất lượng theo ngành hàng | Quản lý ngành hàng, chăm sóc khách hàng | `cube_quality` | 2 |
| UC5 | Phân tầng chăm sóc người bán | Quản lý quan hệ người bán | `cube_seller_abc` | 3 |
| UC6 | Phát hiện người bán lớn có rủi ro chất lượng | Vận hành người bán | `cube_seller_sqr` | 3 |
| UC7 | Giữ chân người bán mới | Phát triển người bán mới | `cube_seller_cohort` | 3 |
| UC8 | Giảm rủi ro phụ thuộc nhà cung cấp | Quản lý ngành hàng, tuyển người bán | `cube_category_seller` | 3 |

| Đòn bẩy của sàn | Use case |
|---|---|
| Tăng quy mô giao dịch | UC1, UC2 |
| Giảm ma sát giao hàng | UC3, UC4 |
| Giữ và phát triển nguồn cung | UC5, UC6, UC7 |
| Giảm rủi ro cấu trúc thị trường | UC8 |

## UC1 — Lập kế hoạch theo mùa vụ

- **Câu hỏi** — Ban điều hành và nhóm kế hoạch muốn biết doanh thu tăng trưởng thế nào theo năm, quý, tháng, và đỉnh mùa vụ rơi vào lúc nào
- **Nguồn** — `cube_time` · Roll-up, Drill-down · Tháng → Quý → Năm · GMV, số đơn, GMV mỗi đơn, điểm đánh giá
- **Đọc kết quả** — So cùng quý giữa các năm, không so hai quý liền kề, vì mùa vụ làm lệch. Mở xuống tháng khi muốn biết đỉnh rơi vào tuần nào của quý. Quý cuối luôn thấp do dữ liệu cắt ngang, không phải sụt giảm.
- **Lợi ích** — Đặt mức tồn kho, nhân sự kho và ngân sách khuyến mãi theo mùa thay vì chia đều cả năm

## UC2 — Phân bổ nguồn lực theo vùng và ngành

- **Câu hỏi** — Nhóm marketing tăng trưởng và phát triển ngành hàng muốn biết doanh thu phân bổ ra sao giữa quý, vùng người bán và ngành hàng
- **Nguồn** — `cube_qrc` · Cube 8 cuboid, Slice, Dice, Pivot · Quý × Vùng người bán × Ngành hàng · GMV, số đơn
- **Đọc kết quả** — Đọc theo hàng để thấy mùa vụ riêng của từng vùng, đọc theo cột để thấy vùng nào tăng nhanh hơn mặt bằng chung. Vùng có tỷ trọng nhỏ nhưng tăng đều là nơi còn dư địa.
- **Lợi ích** — Đặt chỉ tiêu tuyển người bán và ngân sách quảng cáo theo vùng và ngành có dư địa, thay vì chia đều

## UC3 — Ưu tiên đầu tư vận chuyển theo tuyến

- **Câu hỏi** — Nhóm vận hành giao hàng muốn biết tuyến nào giao chậm nhất và khách vùng nào phải mua từ người bán vùng khác
- **Nguồn** — `cube_route` · Roll-up, Pivot · Vùng người bán × Vùng khách · Tỷ lệ dòng hàng giao trễ, số ngày giao, GMV
- **Đọc kết quả** — Đường chéo là tuyến nội vùng và luôn nhanh hơn. Ô càng đậm càng trễ nhiều. Ô xám là tuyến dưới 300 dòng hàng, bỏ qua vì không đủ để kết luận. Tuyến vừa trễ nhiều vừa nhiều đơn là nơi đáng đầu tư trước.
- **Lợi ích** — Chọn đúng tuyến đặt kho trung chuyển và đặt KPI cho nhà vận chuyển, kéo theo điểm đánh giá và tỷ lệ mua lại

## UC4 — Kiểm soát chất lượng theo ngành hàng

- **Câu hỏi** — Nhóm quản lý ngành hàng và chăm sóc khách hàng muốn biết vùng và ngành hàng nào đang cho trải nghiệm kém nhất
- **Nguồn** — `cube_quality` · Roll-up rồi Drill-down · Vùng khách → Ngành hàng · Tỷ lệ dòng hàng giao trễ, số ngày giao, điểm đánh giá
- **Đọc kết quả** — Đọc hai bước: trước ở mức vùng để biết nơi nào kém, rồi mở xuống ngành bên trong vùng đó. Ngành lệch xa vạch 4,16 của toàn sàn là ngành cần can thiệp. Đối chiếu với số ngày giao để biết vấn đề nằm ở vận chuyển hay ở chính sản phẩm.
- **Lợi ích** — Ra quy định đóng gói và thời gian xử lý riêng cho ngành có vấn đề, giảm đánh giá thấp và hoàn hàng

## UC5 — Phân tầng chăm sóc người bán

- **Câu hỏi** — Nhóm quản lý quan hệ người bán muốn biết doanh thu tập trung vào bao nhiêu người bán, và nhóm nào đáng được chăm sóc riêng
- **Nguồn** — `cube_seller_abc` · Grouping sets, Roll-up · Vùng × Hạng ABC · Số người bán, GMV, phần trăm tích luỹ
- **Đọc kết quả** — Đường tích luỹ càng cong sát góc trên trái thì doanh thu càng tập trung. Khoảng cách từ đường tới đường chéo tham chiếu là mức lệch. Đọc tiếp theo vùng để biết nhóm A nằm ở đâu.
- **Lợi ích** — Dồn nguồn lực chăm sóc vào nhóm tạo phần lớn doanh thu, và biết trước thiệt hại nếu nhóm A rời sàn

## UC6 — Phát hiện người bán lớn có rủi ro chất lượng

- **Câu hỏi** — Nhóm vận hành người bán muốn biết người bán quy mô lớn có giữ được chất lượng không và nhóm nào cần hỗ trợ trước
- **Nguồn** — `cube_seller_sqr` · Cube 8 cuboid, Slice, Dice · Quy mô × Chất lượng × Vùng · Số người bán, GMV, tỷ lệ đơn giao trễ
- **Đọc kết quả** — Đọc theo hàng từ trái sang phải. Nếu tỷ lệ trễ tăng dần khi chất lượng giảm thì giao hàng là nguyên nhân chính của điểm thấp. Ô dưới cùng bên phải là nhóm ưu tiên: bán nhiều, điểm thấp, trễ nhiều. Nhấp vào ô để ra danh sách từng người bán.
- **Lợi ích** — Can thiệp vào người bán lớn đang làm xấu trải nghiệm trước khi mất khách, thay vì xử lý sau khi có khiếu nại

## UC7 — Giữ chân người bán mới

- **Câu hỏi** — Nhóm phát triển người bán mới muốn biết người bán vừa gia nhập có bán tiếp ở những quý sau không, và rơi rụng ở quý thứ mấy
- **Nguồn** — `cube_seller_cohort` · Roll-up, Pivot · Quý gia nhập × Quý hoạt động · Số người bán còn hoạt động, GMV
- **Đọc kết quả** — Đọc theo hàng để thấy một nhóm rơi rụng ở quý thứ mấy; tụt mạnh ngay cột Quý 1 nghĩa là mất người bán ngay sau quý đầu. Đọc theo cột để so các nhóm gia nhập với nhau, xem thay đổi trong quy trình onboarding có ăn thua không.
- **Lợi ích** — Tăng tỷ lệ người bán còn hoạt động sau quý đầu, giảm chi phí tuyển mới

## UC8 — Giảm rủi ro phụ thuộc nhà cung cấp

- **Câu hỏi** — Nhóm quản lý ngành hàng và tuyển người bán muốn biết ngành nào đang bị vài người bán chi phối, ngành nào cạnh tranh
- **Nguồn** — `cube_category_seller` · Xếp hạng trên cuboid ngành · Ngành hàng · Số người bán, GMV mỗi người bán, thị phần top 1, HHI
- **Đọc kết quả** — Góc trên bên trái là ngành ít người bán và tập trung cao, rủi ro nhất. Góc dưới bên phải là ngành cạnh tranh. Ngành tập trung cao mà GMV lớn là ngành phải tuyển thêm người bán trước.
- **Lợi ích** — Giảm rủi ro đứt nguồn cung khi một người bán lớn rời sàn hoặc ngừng bán một ngành

HHI: tổng bình phương thị phần × 10.000. Dưới 1.500 cạnh tranh, 1.500–2.500 tập trung vừa, trên 2.500 tập trung cao. Chỉ xét ngành từ 20 người bán trở lên.

## Ba dashboard

| Dashboard | Use case | Biểu đồ |
|---|---|---|
| 1 — Tổng quan sàn | UC1, UC2 | Bốn ô chỉ số, cột doanh thu theo quý, ma trận quý × vùng, tám ngành hàng dẫn đầu |
| 2 — Giao hàng và trải nghiệm | UC3, UC4 | Ma trận tuyến 5×5, giao trễ theo vùng khách, mười ngành điểm đánh giá thấp nhất |
| 3 — Người bán và ngành hàng | UC5, UC6, UC7, UC8 | Đường tích luỹ doanh thu, lưới quy mô × chất lượng, ma trận cohort, phân tán HHI |

## Sáu cube không vào báo cáo chính

Giữ trong script, đặt ở phụ lục.

| Cube | Lý do |
|---|---|
| `cube_seller_focus` | Chỉ là tương quan: người bán đa ngành thường là người bán lớn |
| `cube_region_category_seller` | Trùng cuboid (Vùng, Ngành) của `cube_qrc` |
| `cube_seller_geo_quality` | Trùng ý UC6 và `cube_seller_geo` |
| `cube_seller_reach` | Nhiễu bởi quy mô thị trường vùng, không kết luận nhân quả được |
| `cube_payment` | Snowflake làm mất số kỳ trả góp, câu hỏi còn lại quá hẹp |
| `cube_seller_geo`, `cube_status` | Bối cảnh, không dẫn tới hành động riêng |

`cube_qrc` giữ lại dù giá trị kinh doanh ở mức vừa, vì là chỗ duy nhất dùng `CUBE` đầy đủ 8 cuboid.

## Quy tắc trình bày biểu đồ

- Không tô màu theo vùng địa lý. Dùng một hệ xanh dương đậm nhạt, màu chỉ mang độ lớn.
- Không dùng trục kép. UC5 vẽ đường tích luỹ một trục, kèm đường chéo tham chiếu.
- Ô dưới 300 dòng hàng trong ma trận tuyến tô xám, hiện số lượng thay vì phần trăm.
- Quý cuối tô nhạt kèm chú thích.
- Điểm đánh giá vẽ dạng chấm trên thang đầy đủ 1–5, kèm vạch 4,16 của toàn sàn. Không cắt trục.

## Ghi chú về UC6

`quality_tier = 'Chưa đủ dữ liệu'` xảy ra đúng khi `n_orders < 10`, trùng với `size_tier = '1. <10 đơn'`, nên 7 trong 16 ô của ma trận 4×4 luôn rỗng. Dashboard trình bày thành lưới 3×3 và đưa nhóm dưới 10 đơn xuống dòng ghi chú. Script không sửa.

## Giới hạn khi trình bày

Chi tiết ở `sql/README.md`, mục Giới hạn.

1. Chiều thời gian là ngày giao, quý cuối chưa đủ dữ liệu
2. 775 đơn không có dòng hàng, tỷ lệ đơn thất bại thấp hơn thực tế
3. Review thiếu điền 5,0 cho 645 đơn
4. Dashboard 1 và 2 tính trễ theo dòng hàng, Dashboard 3 theo đơn
5. UC7 đo "còn có đơn trong quý", không phải "còn ở lại sàn"
