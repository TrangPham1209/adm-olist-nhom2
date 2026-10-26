-- =====================================================================
-- 10_cube_generate.sql — KHO DỮ LIỆU VÀ KHỐI DỮ LIỆU OLAP
-- Project : adm-project-olist
-- Dataset : olist_dw
-- Nguồn   : fact_orderitem + Dim_* (lược đồ bông tuyết), olist_preprocessed_all
--
-- PHẦN 0  Điều kiện trước khi chạy
-- PHẦN 1  Giao dịch hợp lệ và điểm đánh giá
-- PHẦN 2  Hai view OLAP
-- PHẦN 3  Kiểm tra nền
-- PHẦN 4  Khối thời gian và địa lý
-- PHẦN 5  Khối giao hàng và chất lượng
-- PHẦN 6  Khối đa chiều, thanh toán, trạng thái
-- PHẦN 7  Truy vấn minh hoạ sáu toán tử OLAP
-- PHẦN 8  Kiểm tra nhất quán của file này
--
-- Thứ tự chạy: 10 (PHẦN 0-3) -> 09 -> 10 (PHẦN 4-8) -> 10a
-- Bảng và khối mức người bán nằm ở file 10a, toán tử join cũng vậy,
-- vì join nối cube_category_seller với cube_quality.
--
-- Quy ước đo lường
--   GMV            SUM(price), không gồm phí vận chuyển
--   Số đơn         COUNT(DISTINCT order_id)
--   w_order        1 / số dòng hàng của đơn
--   Điểm đánh giá  trung bình theo đơn, dùng w_order
--   Tỷ lệ trễ      file 10 theo dòng hàng: AVG(is_late) -> 6,59%
--                  file 10a và 09 theo đơn: SUM(is_late*w_order)/SUM(w_order) -> 6,77%
--   Hai con số này khác nhau có chủ đích. Trong báo cáo gọi riêng là
--   "tỷ lệ dòng hàng giao trễ" và "tỷ lệ đơn giao trễ".
-- =====================================================================


-- =====================================================================
-- PHẦN 0 — ĐIỀU KIỆN TRƯỚC KHI CHẠY
--
-- Script này KHÔNG dựng lại dimension và fact. Phần đó giữ nguyên như
-- nhóm đang có. Chạy câu dưới đây trước, mọi dòng phải là 'ok'.
-- =====================================================================
WITH can_co AS (
  SELECT * FROM UNNEST([
    STRUCT('fact_orderitem'  AS bang, 'order_id'           AS cot),
    ('fact_orderitem',  'order_item_id'),
    ('fact_orderitem',  'delivered_date_key'),
    ('fact_orderitem',  'product_key'),
    ('fact_orderitem',  'seller_key'),
    ('fact_orderitem',  'customer_key'),
    ('fact_orderitem',  'payment_key'),
    ('fact_orderitem',  'status_key'),
    ('fact_orderitem',  'price'),
    ('fact_orderitem',  'freight_value'),
    ('fact_orderitem',  'delivery_days'),
    ('fact_orderitem',  'is_late'),
    ('Dim_Date',        'date_key'),
    ('Dim_Date',        'full_date'),
    ('Dim_Date',        'month_key'),
    ('Dim_Month',       'month_key'),
    ('Dim_Month',       'quarter_key'),
    ('Dim_Quarter',     'quarter_key'),
    ('Dim_Quarter',     'year'),
    ('Dim_Quarter',     'quarter'),
    ('Dim_Product',     'product_key'),
    ('Dim_Product',     'category_key'),
    ('Dim_Category',    'category_key'),
    ('Dim_Category',    'category_en'),
    ('Dim_Seller',      'seller_key'),
    ('Dim_Seller',      'seller_id'),
    ('Dim_Seller',      'city_key'),
    ('Dim_Customer',    'customer_key'),
    ('Dim_Customer',    'customer_unique_id'),
    ('Dim_Customer',    'city_key'),
    ('Dim_City',        'city_key'),
    ('Dim_City',        'city_name'),
    ('Dim_City',        'state_code'),
    ('Dim_State',       'state_code'),
    ('Dim_State',       'region_key'),
    ('Dim_Region',      'region_key'),
    ('Dim_Region',      'region_name'),
    ('Dim_PaymentType', 'payment_type_key'),
    ('Dim_PaymentType', 'payment_type'),
    ('Dim_OrderStatus', 'order_status_key'),
    ('Dim_OrderStatus', 'order_status'),
    ('Dim_OrderStatus', 'status_group')
  ])
)
SELECT c.bang, c.cot, IF(s.column_name IS NULL, 'THIẾU', 'ok') AS tinh_trang
FROM can_co c
LEFT JOIN `adm-project-olist.olist_dw`.INFORMATION_SCHEMA.COLUMNS s
  ON LOWER(s.table_name) = LOWER(c.bang) AND LOWER(s.column_name) = LOWER(c.cot)
ORDER BY tinh_trang DESC, c.bang, c.cot;

-- Dataset olist_preprocessed_all cũng phải tồn tại, PHẦN 1 lấy dữ liệu từ đó.


-- =====================================================================
-- PHẦN 1 — GIAO DỊCH HỢP LỆ VÀ ĐIỂM ĐÁNH GIÁ
-- =====================================================================

-- Danh sách dòng hàng hợp lệ sau bước tiền xử lý. Ít hơn order_items 10 dòng.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.Valid_Txn` AS
SELECT DISTINCT
  order_id,
  SAFE_CAST(order_item_id AS INT64) AS order_item_id
FROM `adm-project-olist.olist_preprocessed_all.olist_preprocessed_all`;

-- Mỗi đơn đúng một điểm đánh giá, lấy bản mới nhất.
-- Nếu nhóm đã có định nghĩa riêng cho view này thì giữ bản của nhóm.
CREATE OR REPLACE VIEW `adm-project-olist.olist_dw.v_review_latest` AS
SELECT order_id, review_score
FROM (
  SELECT
    order_id,
    review_score,
    ROW_NUMBER() OVER (PARTITION BY order_id
                       ORDER BY review_answer_timestamp DESC, review_id) AS rn
  FROM `adm-project-olist.olist_raw.order_reviews`
)
WHERE rn = 1;


-- =====================================================================
-- PHẦN 2 — HAI VIEW OLAP
--
-- v_olap_all  giữ mọi trạng thái đơn, dùng cho cube trạng thái.
-- v_olap      phạm vi đơn hoàn tất, là nguồn của mọi khối còn lại.
--
-- Ba phép nối thời gian phải là LEFT JOIN. Dùng INNER JOIN sẽ loại hết
-- đơn chưa giao, vì các đơn đó không có ngày giao.
-- =====================================================================
CREATE OR REPLACE VIEW `adm-project-olist.olist_dw.v_olap_all` AS
SELECT
  f.order_id,
  f.order_item_id,

  d.full_date,
  dm.month_key   AS month_no,
  dq.quarter_key,
  dq.year,
  dq.quarter,

  cat.category_en,

  s.seller_id,
  sc.city_name   AS seller_city,
  ss.state_code  AS seller_state,
  sr.region_name AS seller_region,

  c.customer_unique_id,
  cc.city_name   AS cust_city,
  cs.state_code  AS cust_state,
  cr.region_name AS cust_region,

  pt.payment_type,
  os.order_status,
  os.status_group,

  f.price,
  f.freight_value,
  f.delivery_days,
  f.is_late,
  rv.review_score,

  1.0 / COUNT(*) OVER (PARTITION BY f.order_id) AS w_order
FROM `adm-project-olist.olist_dw.fact_orderitem` f
JOIN `adm-project-olist.olist_dw.Valid_Txn` v
  ON v.order_id = f.order_id AND v.order_item_id = f.order_item_id
LEFT JOIN `adm-project-olist.olist_dw.v_review_latest` rv ON rv.order_id       = f.order_id
LEFT JOIN `adm-project-olist.olist_dw.Dim_Date`       d   ON d.date_key        = f.delivered_date_key
LEFT JOIN `adm-project-olist.olist_dw.Dim_Month`      dm  ON dm.month_key      = d.month_key
LEFT JOIN `adm-project-olist.olist_dw.Dim_Quarter`    dq  ON dq.quarter_key    = dm.quarter_key
JOIN `adm-project-olist.olist_dw.Dim_Product`      p   ON p.product_key        = f.product_key
JOIN `adm-project-olist.olist_dw.Dim_Category`     cat ON cat.category_key     = p.category_key
JOIN `adm-project-olist.olist_dw.Dim_Seller`       s   ON s.seller_key         = f.seller_key
JOIN `adm-project-olist.olist_dw.Dim_City`         sc  ON sc.city_key          = s.city_key
JOIN `adm-project-olist.olist_dw.Dim_State`        ss  ON ss.state_code        = sc.state_code
JOIN `adm-project-olist.olist_dw.Dim_Region`       sr  ON sr.region_key        = ss.region_key
JOIN `adm-project-olist.olist_dw.Dim_Customer`     c   ON c.customer_key       = f.customer_key
JOIN `adm-project-olist.olist_dw.Dim_City`         cc  ON cc.city_key          = c.city_key
JOIN `adm-project-olist.olist_dw.Dim_State`        cs  ON cs.state_code        = cc.state_code
JOIN `adm-project-olist.olist_dw.Dim_Region`       cr  ON cr.region_key        = cs.region_key
LEFT JOIN `adm-project-olist.olist_dw.Dim_PaymentType` pt ON pt.payment_type_key = f.payment_key
JOIN `adm-project-olist.olist_dw.Dim_OrderStatus`  os  ON os.order_status_key  = f.status_key;

-- Điều kiện quarter_key IS NOT NULL giữ cho v_olap không đổi số liệu
-- mỗi khi v_olap_all thay đổi. Review thiếu điền 5,0 theo bước tiền xử lý.
CREATE OR REPLACE VIEW `adm-project-olist.olist_dw.v_olap` AS
SELECT * REPLACE (COALESCE(review_score, 5.0) AS review_score)
FROM `adm-project-olist.olist_dw.v_olap_all`
WHERE status_group = 'Completed' AND quarter_key IS NOT NULL;


-- =====================================================================
-- PHẦN 3 — KIỂM TRA NỀN
-- Chạy trước khi dựng cube. Sai ở đây thì mọi cube sau đều sai.
-- =====================================================================

-- Số dòng, số đơn, GMV
-- Mong đợi: v_olap_all 112.640 | 98.656 | 13.590.020
--           v_olap     110.187 | 96.468 | 13.219.874
SELECT 'v_olap_all' AS view_name, COUNT(*) AS n_rows,
       COUNT(DISTINCT order_id) AS n_orders, ROUND(SUM(price)) AS gmv
FROM `adm-project-olist.olist_dw.v_olap_all`
UNION ALL
SELECT 'v_olap', COUNT(*), COUNT(DISTINCT order_id), ROUND(SUM(price))
FROM `adm-project-olist.olist_dw.v_olap`;

-- Không mất dòng, không nhân dòng, không thiếu thuộc tính chiều
-- Mong đợi: n_rows = n_grain = n_valid; mọi cột null_* bằng 0 trừ null_review
SELECT
  (SELECT COUNT(*) FROM `adm-project-olist.olist_dw.v_olap_all`) AS n_rows,
  (SELECT COUNT(DISTINCT TO_JSON_STRING(STRUCT(order_id, order_item_id)))
     FROM `adm-project-olist.olist_dw.v_olap_all`)               AS n_grain,
  (SELECT COUNT(*) FROM `adm-project-olist.olist_dw.Valid_Txn`)  AS n_valid,
  COUNTIF(seller_region IS NULL) AS null_seller_region,
  COUNTIF(cust_region   IS NULL) AS null_cust_region,
  COUNTIF(category_en   IS NULL) AS null_category,
  COUNTIF(status_group  IS NULL) AS null_status_group,
  COUNTIF(review_score  IS NULL) AS null_review
FROM `adm-project-olist.olist_dw.v_olap_all`;

-- Mọi trạng thái đơn đều có mặt
-- Mong đợi: delivered 96.468 | shipped 1.106 | canceled 461 | invoiced 312
--           processing 301 | unavailable 6 | approved 2
SELECT status_group, order_status, COUNT(DISTINCT order_id) AS n_orders
FROM `adm-project-olist.olist_dw.v_olap_all`
GROUP BY status_group, order_status
ORDER BY n_orders DESC;

-- Trọng số đúng
-- Mong đợi: tong_w = n_orders = 96.468 | so_don_sai = 0
SELECT
  ROUND(SUM(w_order), 4)   AS tong_w,
  COUNT(DISTINCT order_id) AS n_orders,
  (SELECT COUNT(*) FROM (
     SELECT order_id FROM `adm-project-olist.olist_dw.v_olap`
     GROUP BY order_id HAVING ABS(SUM(w_order) - 1) > 0.000001
   )) AS so_don_sai
FROM `adm-project-olist.olist_dw.v_olap`;


-- =====================================================================
-- PHẦN 4 — KHỐI THỜI GIAN VÀ ĐỊA LÝ
-- =====================================================================

-- CH1 · Doanh thu theo quý, tháng nào kéo kết quả xuống · Dashboard 1
-- Roll-up Tháng → Quý → Năm → Tổng.
-- ky_chua_du đánh dấu kỳ cuối bị cắt ngang, để Tableau tô nhạt cột đó.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_time` AS
WITH r AS (
  SELECT
    year, quarter_key, month_no,
    CASE WHEN GROUPING(month_no)    = 0 THEN 'Tháng'
         WHEN GROUPING(quarter_key) = 0 THEN 'Quý'
         WHEN GROUPING(year)        = 0 THEN 'Năm'
         ELSE 'Tổng' END                                     AS muc,
    ROUND(SUM(price), 2)                                     AS gmv,
    COUNT(DISTINCT order_id)                                 AS n_orders,
    ROUND(SUM(price) / COUNT(DISTINCT order_id), 1)          AS gmv_per_order,
    ROUND(SUM(review_score * w_order) / SUM(w_order), 2)     AS avg_review,
    ROUND(100 * AVG(is_late), 2)                             AS late_pct,
    ROUND(AVG(delivery_days), 1)                             AS avg_days
  FROM `adm-project-olist.olist_dw.v_olap`
  GROUP BY ROLLUP (year, quarter_key, month_no)
),
b AS (
  SELECT MAX(quarter_key) AS max_quarter,
         MAX(month_no)    AS max_month,
         DIV(MAX(quarter_key), 10) AS max_year
  FROM `adm-project-olist.olist_dw.v_olap`
)
SELECT
  r.*,
  CASE r.muc
    WHEN 'Tháng' THEN r.month_no    = b.max_month
    WHEN 'Quý'   THEN r.quarter_key = b.max_quarter
    WHEN 'Năm'   THEN r.year        = b.max_year
    ELSE FALSE
  END                                                        AS ky_chua_du,
  CONCAT(CAST(DIV(r.quarter_key, 10) AS STRING), ' Q',
         CAST(MOD(r.quarter_key, 10) AS STRING))             AS quarter_label,
  CONCAT(CAST(DIV(r.month_no, 100) AS STRING), '-',
         LPAD(CAST(MOD(r.month_no, 100) AS STRING), 2, '0')) AS month_label
FROM r CROSS JOIN b;


-- Phụ lục · Doanh thu theo địa lý người bán
-- Roll-up Vùng → Bang → Thành phố → Tổng.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_geo` AS
SELECT
  seller_region, seller_state, seller_city,
  CASE WHEN GROUPING(seller_city)   = 0 THEN 'Thành phố'
       WHEN GROUPING(seller_state)  = 0 THEN 'Bang'
       WHEN GROUPING(seller_region) = 0 THEN 'Vùng'
       ELSE 'Tổng' END              AS muc,
  ROUND(SUM(price), 2)              AS gmv,
  COUNT(DISTINCT order_id)          AS n_orders,
  COUNT(DISTINCT seller_id)         AS n_sellers,
  ROUND(100 * AVG(is_late), 1)      AS late_pct
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY ROLLUP (seller_region, seller_state, seller_city);


-- =====================================================================
-- PHẦN 5 — KHỐI GIAO HÀNG VÀ CHẤT LƯỢNG
-- =====================================================================

-- Phụ lục · Tuyến vận chuyển vùng sang vùng · không lên dashboard, xem Lưu ý 2
-- du_du_lieu = false là tuyến dưới 300 dòng hàng, Tableau tô xám.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_route` AS
WITH r AS (
  SELECT
    seller_region, cust_region,
    CASE WHEN GROUPING(seller_region) = 1 THEN 'Tổng'
         WHEN GROUPING(cust_region)   = 1 THEN 'Theo vùng bán'
         ELSE 'Tuyến' END          AS muc,
    COUNT(*)                       AS n_items,
    COUNT(DISTINCT order_id)       AS n_orders,
    ROUND(SUM(price), 2)           AS gmv,
    ROUND(AVG(delivery_days), 1)   AS avg_days,
    ROUND(100 * AVG(is_late), 1)   AS late_pct
  FROM `adm-project-olist.olist_dw.v_olap`
  GROUP BY ROLLUP (seller_region, cust_region)
)
SELECT
  r.*,
  r.n_items >= 300                                 AS du_du_lieu,
  COALESCE(r.seller_region = r.cust_region, FALSE) AS tuyen_noi_vung
FROM r;


-- CH3 · Vùng khách nào phàn nàn nhiều, ngành nào là nguyên nhân · Dashboard 2
-- Dùng GROUPING SETS thay vì ROLLUP để có thêm mức ngành hàng độc lập,
-- mức mà biểu đồ mười ngành điểm thấp nhất cần tới.
-- Ba cột *_toan_san lặp trên mọi dòng, để Tableau kẻ vạch tham chiếu.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_quality` AS
WITH r AS (
  SELECT
    cust_region, category_en,
    GROUPING(cust_region)                                AS g_region,
    GROUPING(category_en)                                AS g_cat,
    COUNT(DISTINCT order_id)                             AS n_orders,
    COUNT(*)                                             AS n_items,
    ROUND(100 * AVG(is_late), 1)                         AS late_pct,
    ROUND(AVG(delivery_days), 1)                         AS avg_days,
    ROUND(SUM(review_score * w_order) / SUM(w_order), 2) AS avg_review
  FROM `adm-project-olist.olist_dw.v_olap`
  GROUP BY GROUPING SETS (
    (cust_region, category_en),
    (cust_region),
    (category_en),
    ()
  )
),
tong AS (
  SELECT late_pct AS late_toan_san, avg_review AS review_toan_san, avg_days AS days_toan_san
  FROM r WHERE g_region = 1 AND g_cat = 1
),
xep_hang AS (
  SELECT category_en, RANK() OVER (ORDER BY avg_review) AS hang
  FROM r WHERE g_region = 1 AND g_cat = 0 AND n_orders >= 200
)
SELECT
  r.*,
  t.late_toan_san, t.review_toan_san, t.days_toan_san,
  CASE WHEN r.g_region = 1 AND r.g_cat = 0 THEN x.hang END AS hang_review_thap
FROM r
CROSS JOIN tong t
LEFT JOIN xep_hang x ON x.category_en = r.category_en;


-- =====================================================================
-- PHẦN 6 — KHỐI ĐA CHIỀU, THANH TOÁN, TRẠNG THÁI
-- =====================================================================

-- CH2 · Ngân sách khuyến mãi dồn vào vùng nào, ngành nào · Dashboard 1
-- Cube đầy đủ ba chiều, 2^3 = 8 cuboid.
-- gid = GROUPING(Q)*4 + GROUPING(R)*2 + GROUPING(C)
--   0 (Q,R,C)  1 (Q,R)  2 (Q,C)  3 (Q)  4 (R,C)  5 (R)  6 (C)  7 đỉnh
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_qrc` AS
WITH c AS (
  SELECT
    quarter_key, seller_region, category_en,
    ROUND(SUM(price), 2)     AS gmv,
    COUNT(DISTINCT order_id) AS n_orders,
    GROUPING(quarter_key) * 4 + GROUPING(seller_region) * 2 + GROUPING(category_en) AS gid
  FROM `adm-project-olist.olist_dw.v_olap`
  GROUP BY CUBE (quarter_key, seller_region, category_en)
),
xep_hang AS (
  SELECT category_en, RANK() OVER (ORDER BY gmv DESC) AS hang
  FROM c WHERE gid = 6
)
SELECT
  c.*,
  CASE WHEN c.gid = 6 THEN x.hang END AS hang_gmv_nganh,
  CONCAT(CAST(DIV(c.quarter_key, 10) AS STRING), ' Q',
         CAST(MOD(c.quarter_key, 10) AS STRING)) AS quarter_label
FROM c
LEFT JOIN xep_hang x ON x.category_en = c.category_en;


-- Phụ lục · Cơ cấu hình thức thanh toán
-- Dim_PaymentType chỉ còn loại thanh toán, không còn số kỳ trả góp.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_payment` AS
SELECT
  year, quarter_key, payment_type,
  COUNT(DISTINCT order_id) AS n_orders,
  ROUND(SUM(price), 2)     AS gmv,
  ROUND(AVG(price), 1)     AS avg_item_price
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY GROUPING SETS ((year, payment_type), (quarter_key, payment_type), (payment_type), (year), ());


-- Phụ lục · Cơ cấu trạng thái đơn
-- Cube duy nhất chạy trên v_olap_all, vì cần cả đơn chưa giao.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_status` AS
SELECT
  seller_region, status_group, order_status,
  COUNT(DISTINCT order_id) AS n_orders,
  ROUND(SUM(price), 2)     AS gmv
FROM `adm-project-olist.olist_dw.v_olap_all`
GROUP BY GROUPING SETS (
  (seller_region, status_group, order_status),
  (seller_region, status_group),
  (status_group, order_status),
  (status_group),
  ()
);


-- =====================================================================
-- PHẦN 7 — TRUY VẤN MINH HOẠ CÁC PHÉP OLAP
-- Chụp màn hình các câu này để đưa vào báo cáo.
-- =====================================================================

-- ROLL-UP · từ quý lên năm lên tổng
SELECT muc, year, quarter_label, gmv, n_orders, late_pct, avg_review
FROM `adm-project-olist.olist_dw.cube_time`
WHERE muc IN ('Tổng', 'Năm', 'Quý')
ORDER BY year, quarter_key;

-- DRILL-DOWN · từ quý 2018 Q1 xuống từng tháng
SELECT month_label, gmv, n_orders, avg_review
FROM `adm-project-olist.olist_dw.cube_time`
WHERE muc = 'Tháng' AND DIV(month_no, 100) = 2018 AND MOD(month_no, 100) BETWEEN 1 AND 3
ORDER BY month_no;

-- SLICE · cố định một chiều, lấy lát cắt quý 2018 Q1 của khối ba chiều
SELECT seller_region, category_en, gmv, n_orders
FROM `adm-project-olist.olist_dw.cube_qrc`
WHERE gid = 0 AND quarter_key = 20181
ORDER BY gmv DESC LIMIT 10;

-- DICE · lọc nhiều chiều cùng lúc
SELECT quarter_label, seller_region, category_en, gmv
FROM `adm-project-olist.olist_dw.cube_qrc`
WHERE gid = 0
  AND seller_region IN ('Southeast', 'South')
  AND category_en   IN ('health_beauty', 'watches_gifts', 'bed_bath_table')
  AND quarter_key BETWEEN 20181 AND 20184
ORDER BY quarter_key, seller_region, gmv DESC;

-- PIVOT · xoay vùng thành cột
SELECT
  quarter_label,
  SUM(IF(seller_region = 'Southeast',   gmv, 0)) AS southeast,
  SUM(IF(seller_region = 'South',       gmv, 0)) AS south,
  SUM(IF(seller_region = 'Northeast',   gmv, 0)) AS northeast,
  SUM(IF(seller_region = 'Center-West', gmv, 0)) AS center_west,
  SUM(IF(seller_region = 'North',       gmv, 0)) AS north,
  SUM(gmv) AS tong
FROM `adm-project-olist.olist_dw.cube_qrc`
WHERE gid = 1 AND quarter_key IS NOT NULL AND seller_region IS NOT NULL
GROUP BY quarter_label, quarter_key
ORDER BY quarter_key;

-- CUBE · đếm số ô của từng cuboid
-- Mong đợi 8 dòng, gid 0 tới 7
SELECT gid, COUNT(*) AS so_o, ROUND(SUM(gmv)) AS gmv
FROM `adm-project-olist.olist_dw.cube_qrc`
GROUP BY gid ORDER BY gid;


-- =====================================================================
-- PHẦN 8 — KIỂM TRA NHẤT QUÁN CỦA FILE NÀY
-- Đối chiếu chéo với các bảng của file 10a nằm ở PHẦN 4 của file đó.
-- =====================================================================

-- cube_time: dòng Tổng và đúng một quý bị đánh dấu chưa đủ dữ liệu
-- Mong đợi: Tổng có gmv 13.219.874 | n_orders 96.468 | late_pct 6,59 | avg_review 4,16
SELECT muc, quarter_label, gmv, n_orders, late_pct, avg_review, ky_chua_du
FROM `adm-project-olist.olist_dw.cube_time`
WHERE muc IN ('Tổng', 'Quý') ORDER BY quarter_key;

-- cube_quality: đủ bốn mức
-- Mong đợi: (0,0) 342 dòng | (0,1) 5 vùng | (1,0) 72 ngành | (1,1) 1 dòng
SELECT g_region, g_cat, COUNT(*) AS so_dong
FROM `adm-project-olist.olist_dw.cube_quality`
GROUP BY g_region, g_cat ORDER BY g_region, g_cat;
