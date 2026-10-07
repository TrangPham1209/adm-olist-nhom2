CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.dim_date` AS
WITH all_dates AS (
  SELECT DATE(SAFE_CAST(order_purchase_timestamp     AS TIMESTAMP)) AS d FROM `adm-project-olist.olist_raw.orders`
  UNION ALL SELECT DATE(SAFE_CAST(order_approved_at             AS TIMESTAMP)) FROM `adm-project-olist.olist_raw.orders`
  UNION ALL SELECT DATE(SAFE_CAST(order_delivered_carrier_date  AS TIMESTAMP)) FROM `adm-project-olist.olist_raw.orders`
  UNION ALL SELECT DATE(SAFE_CAST(order_delivered_customer_date AS TIMESTAMP)) FROM `adm-project-olist.olist_raw.orders`
  UNION ALL SELECT DATE(SAFE_CAST(order_estimated_delivery_date AS TIMESTAMP)) FROM `adm-project-olist.olist_raw.orders`
),
bounds AS (
  SELECT
    DATE_TRUNC(MIN(d), YEAR) AS start_date,
    DATE_SUB(DATE_ADD(DATE_TRUNC(MAX(d), YEAR), INTERVAL 1 YEAR), INTERVAL 1 DAY) AS end_date
  FROM all_dates
)
SELECT
  CAST(FORMAT_DATE('%Y%m%d', d) AS INT64) AS date_key,
  d                                       AS full_date,
  EXTRACT(YEAR FROM d)                    AS year,
  EXTRACT(QUARTER FROM d)                 AS quarter,
  EXTRACT(MONTH FROM d)                   AS month,
  EXTRACT(ISOWEEK FROM d)                 AS week,
  EXTRACT(DAY FROM d)                     AS day
FROM bounds, UNNEST(GENERATE_DATE_ARRAY(start_date, end_date)) AS d
UNION ALL
SELECT -1, NULL, NULL, NULL, NULL, NULL, NULL;