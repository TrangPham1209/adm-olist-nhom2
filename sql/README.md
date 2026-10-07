# SQL – Data Warehouse Olist (BigQuery)

Các script dựng star schema cho bộ dữ liệu Olist Brazilian E-Commerce trên Google BigQuery.

- Project: `adm-project-olist`
- Dataset dữ liệu gốc: `olist_raw` (9 bảng import từ file CSV)
- Dataset warehouse: `olist_dw` (các bảng dimension và fact do script tạo ra)

## Cách chạy

Chạy lần lượt theo số thứ tự file, vì dimension phải có trước khi dựng fact.
Trước khi chạy, tạo dataset `olist_dw` (cùng location với `olist_raw`).

| File | Bảng tạo ra | Mô tả |
|---|---|---|
| `00_ref_state_region.sql` | `ref_state_region` | Bảng tra 27 state của Brazil → 5 vùng |
| `01_dim_date.sql` | `dim_date` | Bảng lịch liên tục từ 2016 đến 2018, có dòng `-1` cho ngày không xác định |
| `02_dim_customer.sql` | `dim_customer` | Một dòng mỗi `customer_unique_id`; Region → State → City → ZIP prefix |
| `03_dim_seller.sql` | `dim_seller` | Một dòng mỗi `seller_id`; Region → State → City → ZIP prefix |
| `04_dim_product.sql` | `dim_product` | Category group → Category → Product |
| `05_dim_orderstatus.sql` | `dim_orderstatus` | 8 trạng thái đơn, gom thành Completed / In progress / Failed |
| `06_dim_payment.sql` | `dim_payment` | Loại thanh toán và nhóm thanh toán |
| `07_fact_orderitem.sql` | `fact_orderitem` | Bảng fact, mỗi dòng là một sản phẩm trong đơn |
| `08_olap_demo.sql` | (chỉ có query) | Roll-up, drill-down, slice, dice, pivot, cube |

## Thiết kế chính

- **Grain của fact table**: một dòng trong `order_items` (một sản phẩm trong một đơn).
- **Degenerate dimension**: `order_id`, `order_item_id` nằm trực tiếp trong fact.
- **Gồm có 3 cột ngày** trong fact dùng chung `dim_date` (role-playing): `purchase_date_key`, `delivered_date_key`, `estimated_date_key`. Đơn chưa có ngày giao thì gán `-1`.
- **Khách hàng**: lấy theo `customer_unique_id` (một người có thể có nhiều `customer_id` vì mỗi đơn Olist tạo một `customer_id` mới).
- **Thanh toán**: mỗi đơn lấy loại thanh toán có số tiền lớn nhất làm `payment_key`.
- **Nhóm ngành hàng** (`category_group`) do nhóm tự gom từ khoảng 70 ngành hàng thành 9 nhóm.
- **Số đo trong fact**: `price`, `freight_value`, `item_total`, `delivery_days`, `delay_days`, `is_late`, `review_score`.

## Lưu ý khi dùng dữ liệu

- `review_score` được lặp lại ở mỗi sản phẩm của cùng một đơn. Muốn điểm trung bình theo đơn thì tính theo `order_id` trước, không lấy trung bình trực tiếp trên fact.
- `is_late` và `delay_days` chỉ có giá trị với đơn đã giao (đơn chưa giao là NULL).
- Bảng `product_category_name_translation` khi import bị đặt tên cột `string_field_0`, `string_field_1`, nên `04_dim_product.sql` dùng tên này và bỏ dòng tiêu đề.
- Fact có 98.666 đơn, ít hơn 99.441 đơn trong bảng `orders` vì có khoảng 775 đơn không có sản phẩm nào trong `order_items`.

## Kết quả kiểm tra

Sau khi chạy xong, số dòng đúng là:

| Bảng | Số dòng |
|---|---|
| `dim_date` | khoảng 1.097 (3 năm + dòng `-1`) |
| `dim_customer` | khoảng 96 nghìn |
| `dim_seller` | 3.095 |
| `dim_product` | 32.951 |
| `dim_orderstatus` | 8 |
| `fact_orderitem` | 112.650 (bằng `order_items`) |

Tổng `price` trong fact bằng tổng `price` trong `order_items` (khoảng 13,59 triệu), số đơn khác nhau là 98.666.
