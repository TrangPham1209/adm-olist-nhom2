# SQL — Kho dữ liệu và khối dữ liệu Olist (BigQuery)

Lược đồ bông tuyết. Bảng chiều, bảng sự kiện, hai view OLAP, 4 truy vấn kho, 16 khối dữ liệu, trong đó 6 khối dùng trong báo cáo.

## Dataset

Project `adm-project-olist`.

| Dataset | Nội dung |
|---|---|
| `olist_raw` | 9 bảng CSV gốc từ Kaggle |
| `olist_preprocessed_all` | Kết quả bước tiền xử lý |
| `olist_dw` | Bảng chiều, bảng sự kiện, view, khối dữ liệu |

## File

| File | Nội dung |
|---|---|
| `09_warehouse_queries.sql` | 4 truy vấn nghiệp vụ trên kho, chỉ đọc |
| `10_cube_generate.sql` | 2 view OLAP, 7 khối, 6 truy vấn minh hoạ toán tử |
| `10a_cube_generate.sql` | 4 bảng trung gian người bán, 9 khối người bán, truy vấn minh hoạ join |

Thứ tự chạy:

| Bước | File | Nội dung |
|---|---|---|
| 1 | `10` PHẦN 0–3 | Kiểm tra bảng chiều và bảng sự kiện đã có, dựng `v_olap_all`, `v_olap` |
| 2 | `09` | 4 truy vấn kho. Chỉ đọc, bỏ qua được |
| 3 | `10` PHẦN 4–8 | Khối dữ liệu, truy vấn minh hoạ, kiểm tra |
| 4 | `10a` | Bảng và khối mức người bán, truy vấn join, kiểm tra chéo |

Sửa `v_olap_all` hoặc `v_olap` → chạy lại cả `10` và `10a`, vì khối dữ liệu là bảng vật lý.

## `09_warehouse_queries.sql`

Nguồn `v_olap`. `GROUP BY` thường, không toán tử OLAP. Mỗi truy vấn là phiên bản một cấp tổng hợp của khối tương ứng.

| Mã | Nhu cầu | Khối dữ liệu | Câu hỏi |
|---|---|---|---|
| Q1 | Doanh thu theo quý | `cube_time` | CH1 |
| Q2 | Quý × Vùng người bán × Ngành hàng | `cube_qrc` | CH2 |
| Q3 | Trải nghiệm theo vùng khách × ngành hàng | `cube_quality` | CH3 |
| Q4 | Mức tập trung ngành hàng và trải nghiệm | `cube_category_seller` + `cube_quality` | CH4 |

Cuối file: khối kiểm tra tổng và bảng hạn chế dẫn tới việc dựng khối dữ liệu.

## `10_cube_generate.sql`

**Đầu vào phải có sẵn.** File này **không** dựng lại bảng chiều và bảng sự kiện. 12 bảng `Dim_*` và `fact_orderitem` phải có sẵn trong `olist_dw`; PHẦN 0 là câu truy vấn kiểm tra đủ bảng đủ cột, mọi dòng phải trả `ok`.

**Đối tượng file này dựng ra**

| Đối tượng | Nội dung |
|---|---|
| `Valid_Txn` | Cặp `(order_id, order_item_id)` hợp lệ, từ `olist_preprocessed_all` |
| `v_review_latest` | Mỗi đơn một điểm đánh giá, bản mới nhất |
| `v_olap_all` | Bảng sự kiện nối phẳng với 12 bảng chiều, giữ mọi trạng thái đơn |
| `v_olap` | Phạm vi Completed của `v_olap_all`, điểm đánh giá thiếu điền 5,0 |

`v_olap_all` dùng `LEFT JOIN` với `Dim_Date`, `Dim_Month`, `Dim_Quarter`. `INNER JOIN` sẽ loại hết 2.188 đơn chưa giao.

`v_olap` lọc thêm `quarter_key IS NOT NULL`, giữ cho số liệu không đổi khi `v_olap_all` thay đổi.

**Khối dữ liệu dùng trong báo cáo**

| Bảng | Câu hỏi | Toán tử |
|---|---|---|
| `cube_time` | Doanh thu theo năm, quý, tháng | `ROLLUP` |
| `cube_qrc` | Quý × Vùng × Ngành, 8 cuboid | `CUBE` |
| `cube_quality` | Vùng và ngành nào trải nghiệm kém | `GROUPING SETS` |
| `cube_status` | Cơ cấu trạng thái đơn, chạy trên `v_olap_all` | `GROUPING SETS` |

**`cube_qrc` và cột `gid`**

`gid = GROUPING(quarter_key)*4 + GROUPING(seller_region)*2 + GROUPING(category_en)`. Bit nào bằng 1 thì chiều đó đã bị gộp.

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

Tổng 1.968 ô. Cuboid chi tiết nhất có 1.132 ô trên 3.240 tổ hợp có thể, mật độ khoảng 35%.

**PHẦN 7 — truy vấn minh hoạ toán tử**

| Toán tử | Nguồn | Điều kiện |
|---|---|---|
| Roll-up (merge) | `cube_time` | `muc IN ('Tổng','Năm','Quý')` |
| Drill-down | `cube_time` | `muc = 'Tháng'`, ba tháng của 2018 Q1 |
| Slice | `cube_qrc` | `gid = 0 AND quarter_key = 20181` |
| Dice | `cube_qrc` | `gid = 0`, lọc đồng thời 2 vùng × 3 ngành × 4 quý |
| Pivot | `cube_qrc` | `gid = 1`, xoay vùng thành cột |
| Cube | `cube_qrc` | Đếm số ô từng cuboid, 8 dòng |

Toán tử thứ bảy là join, nằm ở PHẦN 3 của file `10a`.

## `10a_cube_generate.sql`

**Bảng trung gian**

| Bảng | Nội dung | Số dòng |
|---|---|---|
| `seller_perf` | Mỗi người bán một dòng: số đơn, GMV, số ngành, tỷ lệ trễ, số ngày giao, điểm đánh giá, tỷ lệ bán xuyên vùng | 2.970 |
| `seller_tier` | `seller_perf` + phân hạng ABC, quy mô, chất lượng, mức giao hàng | 2.970 |
| `seller_quarter` | Người bán × quý | — |
| `seller_category` | Người bán × ngành hàng | — |

`seller_perf` gom từ `v_olap` nên chỉ có người bán có đơn đã giao: 2.970, ít hơn 3.095 dòng của `Dim_Seller` vì một số người bán chỉ có đơn huỷ hoặc đang xử lý.

**Khối dữ liệu dùng trong báo cáo**

| Bảng | Câu hỏi | Toán tử |
|---|---|---|
| `cube_category_seller` | Ngành hàng nào bị ít người bán chi phối (HHI) | Xếp hạng theo HHI |
| `cube_seller_abc` | Doanh thu tập trung vào bao nhiêu người bán | `GROUPING SETS` |

**PHẦN 3 — truy vấn minh hoạ join**

`hhi` chỉ có ở `cube_category_seller`, `avg_review` và `late_pct` chỉ có ở `cube_quality`. Câu truy vấn nối hai khối qua `category_en`, lấy cấp ngành hàng của `cube_quality` (`g_region = 1 AND g_cat = 0`, tức đã roll-up hết chiều vùng khách). Lọc `du_du_lieu`, tức ngành có từ 20 người bán trở lên — đúng bộ lọc của biểu đồ HHI trên Dashboard 2. Kết quả 49 ngành.

Trên Tableau, phép nối này làm bằng data blending trên `category_en`: Data → Edit Blend Relationships.

## Mức chi tiết

- **Mức chi tiết bảng sự kiện**: một dòng `order_items`. `order_id`, `order_item_id` là degenerate dimension.
- **Khách hàng**: khoá `customer_unique_id`, không dùng `customer_id`.
- **Thành phố**: `Dim_City` dùng chung cho người bán và khách hàng (role-playing dimension). Khoá nhận diện là cặp tên thành phố + mã bang.
- **Thanh toán**: mỗi đơn lấy hình thức có số tiền lớn nhất.
- **Chiều thời gian của view**: ngày giao hàng.
- **`quarter_key`**: năm × 10 + quý, ví dụ 20181. Không trừ trực tiếp được để tính số quý cách nhau; khi cần phải đổi về năm × 4 + quý.
- **`w_order`**: `1 / số dòng hàng của đơn`. Dùng cho các số đo mức đơn, không dùng cho GMV.

## Quy ước đo lường

| Chỉ số | Cách tính |
|---|---|
| GMV | `SUM(price)`, không gồm phí vận chuyển, không nhân `w_order` |
| Số đơn | `COUNT(DISTINCT order_id)` |
| Điểm đánh giá | Theo đơn, trọng số `w_order` |
| Tỷ lệ giao trễ, file `10` | Theo dòng hàng: `AVG(is_late)` → 6,59% |
| Tỷ lệ giao trễ, file `10a` và `09` | Theo đơn: `SUM(is_late * w_order) / SUM(w_order)` → 6,77% |
| Số ngày giao | 12,41 theo dòng hàng · 12,49 theo đơn · xem Lưu ý mục 2 |

Hai cách tính tỷ lệ trễ song song do đơn vị phân tích khác nhau. Trong báo cáo: file `10` gọi là **tỷ lệ dòng hàng giao trễ**, file `10a` và `09` gọi là **tỷ lệ đơn giao trễ**. Không gọi lẫn.

## Số liệu đối chiếu

| Đối tượng | Số dòng | Số đơn | GMV (R$) |
|---|---|---|---|
| `order_items` gốc | 112.650 | — | 13.591.644 |
| `Valid_Txn` | 112.640 | — | — |
| `v_olap_all` | 112.640 | 98.656 | 13.590.020 |
| `v_olap` | 110.187 | 96.468 | 13.219.874 |

Trạng thái đơn trong `v_olap_all`. Dữ liệu gốc có 8 trạng thái, `created` không còn dòng nào sau bước lọc nên `Dim_OrderStatus` giữ 7:

| Nhóm | Chi tiết | Số đơn |
|---|---|---|
| Completed | delivered | 96.468 |
| In progress | shipped 1.106, invoiced 312, processing 301, approved 2 | 1.721 |
| Failed | canceled 461, unavailable 6 | 467 |

Kiểm tra chất lượng, mọi điều kiện phải đúng:

- `v_olap_all` có số dòng bằng `Valid_Txn`, mỗi cặp `(order_id, order_item_id)` chỉ một lần
- Không dòng nào thiếu `seller_region`, `cust_region`, `category_en`, `order_status`, `status_group`
- `quarter_key` chỉ NULL ở đơn chưa giao
- `SUM(w_order)` bằng số đơn, mỗi đơn có tổng trọng số bằng 1
- Mọi bảng chiều có số dòng bằng số khoá phân biệt
- `cube_time` dòng Tổng = `cube_qrc` dòng `gid = 7` = 13.219.874

## Lưu ý

1. Chiều thời gian là ngày giao, không phải ngày đặt. Dữ liệu dừng giữa 2018 nên quý cuối hụt do thiếu dữ liệu, phải cắt hoặc ghi chú.
2. **`delivery_days` chưa phản ánh đúng chênh lệch theo khoảng cách.** Bảng gốc cho 29,3 ngày tới Roraima và 8,7 ngày tới São Paulo, còn số trong kho dồn về quanh 12 ngày ở mọi bang. Nghi do tính ở mức người bán rồi gắn ngược về từng dòng. Chưa sửa, nên không dùng `delivery_days` và `avg_days` để kết luận trong báo cáo.
3. 775 đơn không có dòng hàng nên không vào được bảng sự kiện, phần lớn là `unavailable` và `canceled`. Tỷ lệ đơn thất bại vì vậy thấp hơn thực tế.
4. Điểm đánh giá thiếu điền 5,0 cho 645 đơn. Điểm trung bình 4,162 thay vì 4,156.
5. `Valid_Txn` loại 10 dòng so với `order_items`, do điều kiện lọc ở bước tiền xử lý.
