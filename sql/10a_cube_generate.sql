-- =====================================================================
-- 10a_cube_generate.sql — BẢNG VÀ KHỐI DỮ LIỆU MỨC NGƯỜI BÁN
-- Project : adm-project-olist
-- Dataset : olist_dw
-- Nguồn   : v_olap (tạo ở file 10)
--
-- PHẦN 1  Bảng trung gian mức người bán
-- PHẦN 2  Khối dữ liệu người bán
-- PHẦN 3  Truy vấn minh hoạ toán tử join
-- PHẦN 4  Kiểm tra nhất quán, gồm đối chiếu chéo với file 10
--
-- Chạy sau khi file 10 đã chạy xong. Sửa v_olap thì chạy lại cả 10 và 10a,
-- vì khối dữ liệu là bảng vật lý.
--
-- Từ file này đơn vị phân tích là người bán, nên mọi chỉ số cấp đơn
-- (giao trễ, số ngày giao, điểm đánh giá) tính theo trọng số w_order.
-- =====================================================================


-- =====================================================================
-- PHẦN 1 — BẢNG TRUNG GIAN MỨC NGƯỜI BÁN
--
-- Từ đây đơn vị phân tích là người bán, nên mọi chỉ số cấp đơn
-- (giao trễ, số ngày giao, điểm đánh giá) tính theo trọng số w_order.
-- =====================================================================

CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.seller_perf` AS
SELECT
  seller_id,
  MAX(seller_region)          AS seller_region,
  MAX(seller_state)           AS seller_state,
  MAX(seller_city)            AS seller_city,
  MIN(quarter_key)            AS first_quarter,
  COUNT(DISTINCT quarter_key) AS active_quarters,
  COUNT(DISTINCT order_id)    AS n_orders,
  COUNT(*)                    AS n_items,
  ROUND(SUM(price), 2)        AS gmv,
  ROUND(AVG(price), 1)        AS avg_price,
  COUNT(DISTINCT category_en) AS n_categories,
  ROUND(100 * SUM(is_late       * w_order) / SUM(w_order), 1) AS late_pct,
  ROUND(      SUM(delivery_days * w_order) / SUM(w_order), 1) AS avg_days,
  ROUND(      SUM(review_score  * w_order) / SUM(w_order), 2) AS avg_review,
  ROUND(100 * SUM(IF(cust_region <> seller_region, 1, 0)) / COUNT(*), 1) AS cross_region_pct
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY seller_id;


-- Bốn cách phân hạng. Chất lượng và mức giao hàng chỉ xếp cho người bán
-- từ 10 đơn trở lên, dưới mức đó chưa đủ dữ liệu để kết luận.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.seller_tier` AS
SELECT
  p.*,
  CASE WHEN SUM(gmv) OVER (ORDER BY gmv DESC, seller_id) / SUM(gmv) OVER () <= 0.80
         THEN 'A (80% GMV đầu)'
       WHEN SUM(gmv) OVER (ORDER BY gmv DESC, seller_id) / SUM(gmv) OVER () <= 0.95
         THEN 'B (15% kế)'
       ELSE 'C (5% cuối)' END AS abc_class,
  CASE WHEN n_orders >= 200 THEN '4. >=200 đơn'
       WHEN n_orders >= 50  THEN '3. 50-199 đơn'
       WHEN n_orders >= 10  THEN '2. 10-49 đơn'
       ELSE '1. <10 đơn' END  AS size_tier,
  CASE WHEN n_orders < 10     THEN 'Chưa đủ dữ liệu'
       WHEN avg_review >= 4.0 THEN 'Tốt (>=4.0)'
       WHEN avg_review >= 3.5 THEN 'Trung bình (3.5-4.0)'
       ELSE 'Kém (<3.5)' END  AS quality_tier,
  CASE WHEN n_orders < 10   THEN 'Chưa đủ dữ liệu'
       WHEN late_pct > 15   THEN 'Giao trễ nhiều (>15%)'
       ELSE 'Giao ổn' END    AS delivery_tier
FROM `adm-project-olist.olist_dw.seller_perf` p;


CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.seller_quarter` AS
SELECT
  seller_id, quarter_key,
  ROUND(SUM(price), 2)     AS gmv,
  COUNT(DISTINCT order_id) AS n_orders
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY seller_id, quarter_key;


CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.seller_category` AS
SELECT
  seller_id,
  MAX(seller_region)   AS seller_region,
  category_en,
  ROUND(SUM(price), 2) AS gmv
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY seller_id, category_en;


-- =====================================================================
-- PHẦN 2 — KHỐI DỮ LIỆU NGƯỜI BÁN
-- =====================================================================

-- Bổ trợ CH4 · Phân loại ABC người bán · Dashboard 2
-- Ba ô chỉ số A, B, C.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_abc` AS
WITH r AS (
  SELECT
    seller_region, abc_class,
    GROUPING(seller_region)                              AS g_region,
    GROUPING(abc_class)                                  AS g_abc,
    COUNT(*)                                             AS n_sellers,
    ROUND(SUM(gmv), 0)                                   AS gmv,
    SUM(n_orders)                                        AS n_orders,
    ROUND(SUM(avg_review * n_orders) / SUM(n_orders), 2) AS avg_review,
    ROUND(SUM(late_pct   * n_orders) / SUM(n_orders), 1) AS late_pct
  FROM `adm-project-olist.olist_dw.seller_tier`
  GROUP BY GROUPING SETS ((seller_region, abc_class), (abc_class), (seller_region), ())
),
tong AS (
  SELECT n_sellers AS tong_sellers, gmv AS tong_gmv
  FROM r WHERE g_region = 1 AND g_abc = 1
)
SELECT
  r.*,
  ROUND(100 * r.n_sellers / t.tong_sellers, 1) AS pct_sellers,
  ROUND(100 * r.gmv       / t.tong_gmv, 1)     AS pct_gmv
FROM r CROSS JOIN tong t;


-- Phụ lục · Đường tích luỹ doanh thu theo người bán
-- Mỗi người bán một dòng, xếp theo GMV giảm dần.
-- Tableau vẽ pct_sellers với pct_gmv; cột pct_chia_deu cho đường chéo tham chiếu.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_pareto` AS
WITH s AS (
  SELECT
    seller_id, seller_region, abc_class, gmv, n_orders,
    ROW_NUMBER() OVER (ORDER BY gmv DESC, seller_id) AS thu_tu,
    SUM(gmv)     OVER (ORDER BY gmv DESC, seller_id) AS gmv_tich_luy,
    COUNT(*)     OVER ()                             AS tong_sellers,
    SUM(gmv)     OVER ()                             AS tong_gmv
  FROM `adm-project-olist.olist_dw.seller_tier`
)
SELECT
  seller_id, seller_region, abc_class, thu_tu, gmv, n_orders,
  ROUND(100 * thu_tu       / tong_sellers, 3) AS pct_sellers,
  ROUND(100 * gmv_tich_luy / tong_gmv, 3)     AS pct_gmv,
  ROUND(100 * thu_tu       / tong_sellers, 3) AS pct_chia_deu
FROM s;


-- Phụ lục · Người bán lớn có rủi ro chất lượng
-- Cube đầy đủ ba chiều, 8 cuboid.
-- gid = GROUPING(size)*4 + GROUPING(quality)*2 + GROUPING(region)
-- Dashboard lấy gid = 0 rồi lọc bỏ nhóm dưới 10 đơn, còn lưới 3×3.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_sqr` AS
SELECT
  size_tier, quality_tier, seller_region,
  COUNT(*)                                             AS n_sellers,
  ROUND(SUM(gmv), 0)                                   AS gmv,
  SUM(n_orders)                                        AS n_orders,
  ROUND(SUM(late_pct   * n_orders) / SUM(n_orders), 1) AS late_pct,
  ROUND(SUM(avg_review * n_orders) / SUM(n_orders), 2) AS avg_review,
  GROUPING(size_tier) * 4 + GROUPING(quality_tier) * 2 + GROUPING(seller_region) AS gid
FROM `adm-project-olist.olist_dw.seller_tier`
GROUP BY CUBE (size_tier, quality_tier, seller_region);


-- Phụ lục · Giữ chân người bán mới
-- quarter_key mã hoá kiểu năm × 10 + quý nên trừ trực tiếp cho ra số sai
-- (20174 sang 20181 cách nhau 1 quý nhưng hiệu là 7). Phải quy về chỉ số
-- quý liên tục: năm × 4 + quý.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_cohort` AS
WITH base AS (
  SELECT
    sq.seller_id,
    sq.quarter_key  AS active_quarter,
    sq.gmv,
    sq.n_orders,
    t.first_quarter AS cohort_quarter
  FROM `adm-project-olist.olist_dw.seller_quarter` sq
  JOIN `adm-project-olist.olist_dw.seller_perf` t USING (seller_id)
),
agg AS (
  SELECT
    cohort_quarter,
    active_quarter,
    (DIV(active_quarter, 10) * 4 + MOD(active_quarter, 10))
      - (DIV(cohort_quarter, 10) * 4 + MOD(cohort_quarter, 10)) AS period_number,
    COUNT(DISTINCT seller_id) AS active_sellers,
    ROUND(SUM(gmv), 0)        AS gmv,
    SUM(n_orders)             AS n_orders
  FROM base
  GROUP BY cohort_quarter, active_quarter
),
quy_mo AS (
  SELECT cohort_quarter, active_sellers AS cohort_size
  FROM agg WHERE period_number = 0
),
b AS (
  SELECT MAX(DIV(quarter_key, 10) * 4 + MOD(quarter_key, 10)) AS max_qi
  FROM `adm-project-olist.olist_dw.seller_quarter`
)
SELECT
  a.cohort_quarter,
  a.active_quarter,
  a.period_number,
  a.active_sellers,
  q.cohort_size,
  ROUND(100 * a.active_sellers / q.cohort_size, 1) AS retention_pct,
  a.gmv,
  a.n_orders,
  CONCAT(CAST(DIV(a.cohort_quarter, 10) AS STRING), ' Q',
         CAST(MOD(a.cohort_quarter, 10) AS STRING))  AS cohort_label,
  CONCAT('Quý ', CAST(a.period_number AS STRING))    AS period_label,
  b.max_qi - (DIV(a.cohort_quarter, 10) * 4 + MOD(a.cohort_quarter, 10)) AS so_quy_theo_doi_duoc
FROM agg a
JOIN quy_mo q USING (cohort_quarter)
CROSS JOIN b;


-- CH4 · Ngành hàng nào phụ thuộc quá ít người bán · Dashboard 2
-- HHI = tổng bình phương thị phần × 10.000.
-- Dưới 1.500 cạnh tranh | 1.500-2.500 tập trung vừa | trên 2.500 tập trung cao.
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_category_seller` AS
WITH s AS (
  SELECT *, gmv / SUM(gmv) OVER (PARTITION BY category_en) AS share
  FROM `adm-project-olist.olist_dw.seller_category`
)
SELECT
  category_en,
  COUNT(*)                          AS n_sellers,
  ROUND(SUM(gmv), 0)                AS gmv,
  ROUND(SUM(gmv) / COUNT(*), 0)     AS gmv_per_seller,
  ROUND(100 * MAX(share), 1)        AS top1_share_pct,
  ROUND(10000 * SUM(share * share), 0) AS hhi,
  COUNT(*) >= 20                    AS du_du_lieu
FROM s
GROUP BY category_en;


-- Phụ lục · Vùng nào có người bán chuyên ngành nào
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_region_category_seller` AS
SELECT
  seller_region, category_en,
  COUNT(DISTINCT seller_id) AS n_sellers,
  ROUND(SUM(gmv), 0)        AS gmv
FROM `adm-project-olist.olist_dw.seller_category`
GROUP BY ROLLUP (seller_region, category_en);


-- Phụ lục · Bán một ngành hay nhiều ngành
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_focus` AS
SELECT
  CASE WHEN n_categories = 1  THEN '1 ngành'
       WHEN n_categories <= 3 THEN '2-3 ngành'
       ELSE '>=4 ngành' END AS focus_tier,
  size_tier,
  COUNT(*)                                             AS n_sellers,
  ROUND(SUM(gmv), 0)                                   AS gmv,
  ROUND(SUM(gmv) / COUNT(*), 0)                        AS gmv_per_seller,
  ROUND(SUM(avg_review * n_orders) / SUM(n_orders), 2) AS avg_review,
  ROUND(SUM(late_pct   * n_orders) / SUM(n_orders), 1) AS late_pct
FROM `adm-project-olist.olist_dw.seller_tier`
GROUP BY ROLLUP (focus_tier, size_tier);


-- Phụ lục · Bán xuyên vùng và chất lượng giao hàng
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_reach` AS
SELECT
  seller_region,
  CASE WHEN cross_region_pct < 10 THEN 'Nội vùng (<10%)'
       WHEN cross_region_pct < 40 THEN 'Hỗn hợp (10-40%)'
       ELSE 'Xuyên vùng (>=40%)' END AS reach_tier,
  COUNT(*)                                             AS n_sellers,
  ROUND(SUM(gmv), 0)                                   AS gmv,
  ROUND(SUM(avg_days   * n_orders) / SUM(n_orders), 1) AS avg_days,
  ROUND(SUM(late_pct   * n_orders) / SUM(n_orders), 1) AS late_pct,
  ROUND(SUM(avg_review * n_orders) / SUM(n_orders), 2) AS avg_review
FROM `adm-project-olist.olist_dw.seller_tier`
GROUP BY GROUPING SETS ((seller_region, reach_tier), (reach_tier), (seller_region), ());


-- Phụ lục · Bang và thành phố tập trung người bán kém
CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.cube_seller_geo_quality` AS
SELECT
  seller_state, seller_city,
  COUNT(*)                                         AS n_sellers,
  COUNT(IF(quality_tier = 'Kém (<3.5)', 1, NULL))  AS n_poor,
  COUNT(IF(delivery_tier LIKE 'Giao trễ%', 1, NULL)) AS n_late,
  ROUND(SUM(gmv), 2)                               AS gmv
FROM `adm-project-olist.olist_dw.seller_tier`
GROUP BY ROLLUP (seller_state, seller_city);


-- =====================================================================
-- PHẦN 3 — TRUY VẤN MINH HOẠ TOÁN TỬ JOIN
-- Chụp màn hình câu này để đưa vào báo cáo.
-- Sáu toán tử còn lại minh hoạ ở PHẦN 7 của file 10.
-- =====================================================================

-- JOIN · nối hai khối qua chiều chung category_en để lấy measure của cả hai
-- hhi chỉ có ở cube_category_seller, avg_review và late_pct chỉ có ở cube_quality.
-- Cấp ngành hàng của cube_quality là g_region = 1 AND g_cat = 0, tức đã roll-up
-- hết chiều vùng khách.
-- Lọc du_du_lieu = ngành có từ 20 người bán trở lên, đúng bộ lọc của biểu đồ HHI
-- trên Dashboard 2. Mong đợi 49 dòng.
SELECT
  s.category_en,
  s.n_sellers,
  s.hhi,
  CASE WHEN s.hhi >= 2500 THEN 'Tập trung cao'
       WHEN s.hhi >= 1500 THEN 'Tập trung vừa'
       ELSE 'Cạnh tranh' END AS muc_tap_trung,
  q.avg_review,
  q.late_pct,
  s.gmv
FROM `adm-project-olist.olist_dw.cube_category_seller` s
JOIN `adm-project-olist.olist_dw.cube_quality` q
  USING (category_en)
WHERE q.g_region = 1 AND q.g_cat = 0
  AND s.du_du_lieu
ORDER BY s.hhi DESC;


-- =====================================================================
-- PHẦN 4 — KIỂM TRA NHẤT QUÁN
-- =====================================================================

-- Cube tổng quát khớp nhau và khớp v_olap
-- Mong đợi: mọi cột true
SELECT
  (SELECT gmv FROM `adm-project-olist.olist_dw.cube_time` WHERE muc = 'Tổng')
    = (SELECT gmv FROM `adm-project-olist.olist_dw.cube_qrc` WHERE gid = 7)                   AS time_khop_qrc,
  ABS((SELECT SUM(gmv) FROM `adm-project-olist.olist_dw.cube_seller_geo` WHERE muc = 'Thành phố')
      - (SELECT gmv FROM `adm-project-olist.olist_dw.cube_qrc` WHERE gid = 7)) < 1             AS geo_khop,
  ABS((SELECT SUM(gmv) FROM `adm-project-olist.olist_dw.cube_route` WHERE muc = 'Tuyến')
      - (SELECT gmv FROM `adm-project-olist.olist_dw.cube_qrc` WHERE gid = 7)) < 1             AS route_khop,
  ABS((SELECT SUM(gmv) FROM `adm-project-olist.olist_dw.seller_tier`)
      - (SELECT SUM(price) FROM `adm-project-olist.olist_dw.v_olap`)) < 1                      AS seller_khop_v_olap,
  (SELECT SUM(n_sellers) FROM `adm-project-olist.olist_dw.cube_seller_sqr` WHERE gid = 0)
    = (SELECT COUNT(*) FROM `adm-project-olist.olist_dw.seller_tier`)                          AS sqr_dem_du;


-- cube_seller_pareto: điểm cuối phải chạm 100%
-- Mong đợi: hai cột phần trăm đều bằng 100,0
SELECT COUNT(*) AS so_nguoi_ban,
       ROUND(MAX(pct_gmv), 1)     AS pct_gmv_cuoi,
       ROUND(MAX(pct_sellers), 1) AS pct_sellers_cuoi
FROM `adm-project-olist.olist_dw.cube_seller_pareto`;

-- cube_seller_cohort: period_number không âm, quý 0 luôn 100%
-- Mong đợi: so_dong_sai = 0
SELECT COUNTIF(period_number < 0) AS period_am,
       COUNTIF(period_number = 0 AND retention_pct <> 100.0) AS quy_0_sai
FROM `adm-project-olist.olist_dw.cube_seller_cohort`;

-- cube_seller_abc: ba hạng cộng lại 100%
SELECT abc_class, n_sellers, pct_sellers, gmv, pct_gmv
FROM `adm-project-olist.olist_dw.cube_seller_abc`
WHERE g_region = 1 AND g_abc = 0 ORDER BY abc_class;
