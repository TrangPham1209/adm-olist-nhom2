-- =====================================================
-- 08_olap_demo.sql
-- Minh họa các thao tác OLAP trên star schema Olist
-- Bôi đen từng câu rồi bấm Run để xem kết quả
-- =====================================================


-- 1. ROLL-UP: gộp từ quý lên năm, kèm tổng
SELECT
  CASE WHEN GROUPING(d.year)    = 1 THEN 'ALL YEARS'    ELSE CAST(d.year    AS STRING) END AS year,
  CASE WHEN GROUPING(d.quarter) = 1 THEN 'ALL QUARTERS' ELSE CAST(d.quarter AS STRING) END AS quarter,
  COUNT(DISTINCT f.order_id)      AS orders,
  CAST(ROUND(SUM(f.price)) AS INT64) AS revenue
FROM `adm-project-olist.olist_dw.fact_orderitem` f
JOIN `adm-project-olist.olist_dw.dim_date` d ON d.date_key = f.purchase_date_key
GROUP BY ROLLUP(d.year, d.quarter)
ORDER BY d.year, d.quarter;


-- 2. DRILL-DOWN: từ năm 2017 xuống từng tháng
SELECT
  d.year, d.quarter, d.month,
  ROUND(SUM(f.price), 0) AS revenue
FROM `adm-project-olist.olist_dw.fact_orderitem` f
JOIN `adm-project-olist.olist_dw.dim_date` d ON d.date_key = f.purchase_date_key
WHERE d.year = 2017
GROUP BY d.year, d.quarter, d.month
ORDER BY d.month;


-- 3. SLICE: chỉ lấy khách vùng Southeast
SELECT
  p.category_group,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(SUM(f.price), 0)     AS revenue
FROM `adm-project-olist.olist_dw.fact_orderitem` f
JOIN `adm-project-olist.olist_dw.dim_customer` c ON c.customer_key = f.customer_key
JOIN `adm-project-olist.olist_dw.dim_product`  p ON p.product_key  = f.product_key
WHERE c.region = 'Southeast'
GROUP BY p.category_group
ORDER BY revenue DESC;


-- 4. DICE: nhiều điều kiện cùng lúc, tính tỷ lệ giao trễ
SELECT
  c.region, p.category_group,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(AVG(f.is_late), 3)   AS late_rate
FROM `adm-project-olist.olist_dw.fact_orderitem` f
JOIN `adm-project-olist.olist_dw.dim_date`     d ON d.date_key     = f.purchase_date_key
JOIN `adm-project-olist.olist_dw.dim_customer` c ON c.customer_key = f.customer_key
JOIN `adm-project-olist.olist_dw.dim_product`  p ON p.product_key  = f.product_key
WHERE d.year IN (2017, 2018)
  AND c.region IN ('Southeast', 'Northeast')
  AND p.category_group IN ('Electronics', 'Home', 'Fashion')
GROUP BY c.region, p.category_group
ORDER BY late_rate DESC;


-- 5. PIVOT: xoay năm thành cột
SELECT
  p.category_group,
  ROUND(SUM(CASE WHEN d.year = 2016 THEN f.price END), 0) AS rev_2016,
  ROUND(SUM(CASE WHEN d.year = 2017 THEN f.price END), 0) AS rev_2017,
  ROUND(SUM(CASE WHEN d.year = 2018 THEN f.price END), 0) AS rev_2018
FROM `adm-project-olist.olist_dw.fact_orderitem` f
JOIN `adm-project-olist.olist_dw.dim_date`    d ON d.date_key    = f.purchase_date_key
JOIN `adm-project-olist.olist_dw.dim_product` p ON p.product_key = f.product_key
GROUP BY p.category_group
ORDER BY rev_2017 DESC;


-- 6. CUBE (thêm): tổng hợp mọi tổ hợp của 3 chiều (2^3 = 8 cuboid)
SELECT
  d.year, c.region, p.category_group,
  ROUND(SUM(f.price), 0) AS revenue
FROM `adm-project-olist.olist_dw.fact_orderitem` f
JOIN `adm-project-olist.olist_dw.dim_date`     d ON d.date_key     = f.purchase_date_key
JOIN `adm-project-olist.olist_dw.dim_customer` c ON c.customer_key = f.customer_key
JOIN `adm-project-olist.olist_dw.dim_product`  p ON p.product_key  = f.product_key
GROUP BY CUBE(d.year, c.region, p.category_group);