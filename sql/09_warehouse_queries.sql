/* =============================================================================
   09_warehouse_queries.sql — Truy vấn kho dữ liệu theo nhu cầu thực tế

   Nguồn      : adm-project-olist.olist_dw.v_olap
   Toán tử    : GROUP BY thường. Không ROLLUP / CUBE / GROUPING SETS.
   Tác động   : chỉ đọc, không tạo bảng.
   Thứ tự chạy: 10 (phần kho) -> 10 (phần cube) -> 10a -> 09

   Mỗi truy vấn ở đây là phiên bản MỘT CẤP TỔNG HỢP của một khối dữ liệu.
   Khối dữ liệu tương ứng giữ nguyên các cột đó và bổ sung các cấp còn lại.

   | Truy vấn | Nhu cầu                          | Khối dữ liệu                          | Câu hỏi |
   |----------|----------------------------------|---------------------------------------|-----|
   | Q1       | Doanh thu theo quý               | cube_time                             | CH1 |
   | Q2       | Quý x Vùng bán x Ngành hàng      | cube_qrc                              | CH2 |
   | Q3       | Trải nghiệm theo vùng khách/ngành| cube_quality                          | CH3 |
   | Q4       | Tập trung ngành hàng và trải nghiệm | cube_category_seller + cube_quality | CH4 |

   Trước khi chạy: đối chiếu tên dataset và tên cột với v_olap của nhóm.
============================================================================= */

-- =============================================================================
-- Q1. Doanh thu theo quý
-- Nhu cầu  : Ban điều hành xem doanh thu tăng hay giảm, đỉnh mùa vụ ở quý nào
-- Cube     : cube_time
-- Biểu đồ  : DB1 Doanh thu theo quy, K1-K4
-- Kỳ vọng  : 9 dòng (2016 Q4 .. 2018 Q3); 2018 Q4 chỉ 3 đơn
-- Cube thêm: cấp tháng, cấp năm, dòng tổng toàn sàn
-- =============================================================================
SELECT
    quarter_key,
    CONCAT(CAST(DIV(quarter_key, 10) AS STRING), ' Q',
           CAST(MOD(quarter_key, 10) AS STRING))          AS quarter_label,
    COUNT(*)                                              AS so_dong_hang,
    COUNT(DISTINCT order_id)                              AS so_don,
    ROUND(SUM(price), 2)                                  AS gmv,
    ROUND(SUM(review_score * w_order) / SUM(w_order), 3)  AS diem_danh_gia,
    ROUND(SUM(is_late * w_order) / SUM(w_order) * 100, 2) AS ty_le_don_tre,
    ROUND(SUM(delivery_days * w_order) / SUM(w_order), 2) AS so_ngay_giao
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY quarter_key, quarter_label
ORDER BY quarter_key;


-- =============================================================================
-- Q2. Doanh thu theo Quý x Vùng người bán x Ngành hàng
-- Nhu cầu  : Marketing xem doanh thu phân bổ ra sao giữa ba chiều này
-- Cube     : cube_qrc, tương ứng cuboid chi tiết nhất gid = 0
-- Biểu đồ  : DB1 Quy x Vung, DB1 Top nganh hang
-- Cube thêm: 7 cuboid còn lại, gồm mọi tổ hợp hai chiều, một chiều và tổng
-- =============================================================================
SELECT
    quarter_key,
    CONCAT(CAST(DIV(quarter_key, 10) AS STRING), ' Q',
           CAST(MOD(quarter_key, 10) AS STRING)) AS quarter_label,
    seller_region,
    category_en,
    COUNT(DISTINCT order_id)                     AS so_don,
    ROUND(SUM(price), 2)                         AS gmv
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY quarter_key, quarter_label, seller_region, category_en
ORDER BY quarter_key, gmv DESC;


-- =============================================================================
-- Q3. Trải nghiệm theo vùng khách hàng và ngành hàng
-- Nhu cầu  : Quản lý ngành hàng tìm vùng và ngành cho trải nghiệm kém nhất
-- Cube     : cube_quality, tương ứng tổ hợp vùng x ngành
-- Biểu đồ  : DB2 Giao tre theo vung khach, DB2 Nganh diem thap
-- Cube thêm: cấp vùng khách đứng riêng và cấp ngành hàng đứng riêng
-- Lưu ý    : lọc tối thiểu 200 đơn để điểm đánh giá đủ tin cậy
-- =============================================================================
SELECT
    cust_region,
    category_en,
    COUNT(DISTINCT order_id)                              AS so_don,
    ROUND(SUM(price), 2)                                  AS gmv,
    ROUND(SUM(review_score * w_order) / SUM(w_order), 3)  AS diem_danh_gia,
    ROUND(SUM(is_late * w_order) / SUM(w_order) * 100, 2) AS ty_le_don_tre,
    ROUND(SUM(delivery_days * w_order) / SUM(w_order), 2) AS so_ngay_giao
FROM `adm-project-olist.olist_dw.v_olap`
GROUP BY cust_region, category_en
HAVING COUNT(DISTINCT order_id) >= 200
ORDER BY diem_danh_gia ASC;

-- =============================================================================
-- Q4. Mức tập trung ngành hàng và trải nghiệm khách hàng
-- Nhu cầu  : Nhóm tuyển người bán tìm ngành bị ít người bán chi phối và xem
--            trải nghiệm ở đó có kém hơn không
-- Khối     : cube_category_seller (hhi) JOIN cube_quality (avg_review, late_pct)
-- Biểu đồ  : DB3 HHI nganh hang trên Dashboard 2, phân tán HHI x điểm đánh giá
-- Kỳ vọng  : 49 ngành sau khi lọc; HHI tương quan -0,342 với điểm đánh giá
-- Bộ lọc   : từ 20 người bán trở lên, khớp cột du_du_lieu của cube_category_seller
--            và khớp bộ lọc của biểu đồ HHI trên Dashboard 2
-- HHI      : tổng bình phương thị phần người bán trong ngành, thang 0-10.000
-- =============================================================================
WITH cat_seller AS (
    SELECT category_en, seller_id, SUM(price) AS gmv_seller
    FROM `adm-project-olist.olist_dw.v_olap`
    GROUP BY category_en, seller_id
),
cat_tot AS (
    SELECT category_en, COUNT(*) AS n_sellers, SUM(gmv_seller) AS gmv_cat
    FROM cat_seller
    GROUP BY category_en
),
cat_hhi AS (
    SELECT s.category_en,
           ROUND(SUM(POW(100 * s.gmv_seller / t.gmv_cat, 2)), 0) AS hhi
    FROM cat_seller s
    JOIN cat_tot t USING (category_en)
    GROUP BY s.category_en
),
cat_exp AS (
    SELECT category_en,
           COUNT(DISTINCT order_id)                              AS n_orders,
           ROUND(SUM(review_score * w_order) / SUM(w_order), 3)  AS avg_review,
           ROUND(SUM(is_late * w_order) / SUM(w_order) * 100, 2) AS late_pct,
           ROUND(SUM(delivery_days * w_order) / SUM(w_order), 2) AS avg_days
    FROM `adm-project-olist.olist_dw.v_olap`
    GROUP BY category_en
)
SELECT
    t.category_en,
    t.n_sellers,
    ROUND(t.gmv_cat, 2) AS gmv,
    h.hhi,
    CASE WHEN h.hhi < 1500 THEN 'Cạnh tranh'
         WHEN h.hhi < 2500 THEN 'Tập trung vừa'
         ELSE 'Tập trung cao' END AS muc_tap_trung,
    e.n_orders,
    e.avg_review,
    e.late_pct,
    e.avg_days
FROM cat_tot t
JOIN cat_hhi h USING (category_en)
JOIN cat_exp e USING (category_en)
WHERE t.n_sellers >= 20
ORDER BY h.hhi DESC;


-- =============================================================================
-- KIỂM TRA. Tổng của Q1 phải khớp số liệu kho
-- Kỳ vọng  : 110.187 dòng | 96.468 đơn | GMV 13.219.874
-- =============================================================================
SELECT
    COUNT(*)                 AS so_dong,
    COUNT(DISTINCT order_id) AS so_don,
    ROUND(SUM(price), 2)     AS gmv
FROM `adm-project-olist.olist_dw.v_olap`;


/* =============================================================================
   HẠN CHẾ CỦA BƯỚC NÀY -> TIỀN ĐỀ DỰNG CUBE

   | Hạn chế                       | Biểu hiện                                 |
   |-------------------------------|-------------------------------------------|
   | Quét lại toàn bộ dữ liệu      | 4 câu hỏi = 4 lần quét 110.187 dòng       |
   | Đổi mức tổng hợp phải sửa SQL | Q1 cố định cấp quý; muốn tháng/năm sửa lại|
   | Không có dòng tổng            | Q2 không có tổng theo vùng, ngành, toàn sàn|

   Cube giữ nguyên cột của truy vấn và bổ sung phần thiếu:

   | Truy vấn | Cube                                | Phần được bổ sung           |
   |----------|-------------------------------------|-----------------------------|
   | Q1       | cube_time                           | cấp tháng, năm, dòng tổng   |
   | Q2       | cube_qrc                            | 7 cuboid còn lại            |
   | Q3       | cube_quality                        | cấp vùng riêng, ngành riêng |
   | Q4       | cube_category_seller + cube_quality | tách hai cube, nối bằng JOIN |

   Vì cube giữ nguyên cột, biểu đồ ở Dashboard 1 và 2 đọc được cả hai nguồn:
   kết quả truy vấn (một cấp) hoặc cube (mọi cấp). Không cần sheet riêng cho
   bước truy vấn kho.

   Chi tiết: 10_cube_generate.sql, 10a_cube_generate.sql, README_analysis.md
============================================================================= */
