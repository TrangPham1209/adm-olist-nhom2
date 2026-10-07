CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.dim_customer` AS
WITH one_per_person AS (
  SELECT
    customer_unique_id,
    ARRAY_AGG(STRUCT(customer_zip_code_prefix, customer_city, customer_state)
              ORDER BY customer_id LIMIT 1)[OFFSET(0)] AS loc
  FROM `adm-project-olist.olist_raw.customers`
  GROUP BY customer_unique_id
)
SELECT
  ROW_NUMBER() OVER (ORDER BY customer_unique_id)              AS customer_key,
  customer_unique_id,
  COALESCE(r.region, 'Không xác định')                         AS region,
  loc.customer_state                                           AS state,
  INITCAP(loc.customer_city)                                   AS city,
  LPAD(CAST(loc.customer_zip_code_prefix AS STRING), 5, '0')   AS zip_prefix
FROM one_per_person p
LEFT JOIN `adm-project-olist.olist_dw.ref_state_region` r
  ON r.state = p.loc.customer_state;