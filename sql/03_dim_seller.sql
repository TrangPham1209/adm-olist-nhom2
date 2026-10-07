CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.dim_seller` AS
SELECT
  ROW_NUMBER() OVER (ORDER BY s.seller_id)                     AS seller_key,
  s.seller_id,
  COALESCE(r.region, 'Không xác định')                         AS region,
  s.seller_state                                               AS state,
  INITCAP(s.seller_city)                                       AS city,
  LPAD(CAST(s.seller_zip_code_prefix AS STRING), 5, '0')       AS zip_prefix
FROM `adm-project-olist.olist_raw.sellers` s
LEFT JOIN `adm-project-olist.olist_dw.ref_state_region` r
  ON r.state = s.seller_state;