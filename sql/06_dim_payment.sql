CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.dim_payment` AS
SELECT
  ROW_NUMBER() OVER (ORDER BY payment_type) AS payment_key,
  payment_type,
  CASE
    WHEN payment_type IN ('credit_card','debit_card') THEN 'Card'
    WHEN payment_type = 'boleto'  THEN 'Boleto'
    WHEN payment_type = 'voucher' THEN 'Voucher'
    ELSE 'Other'
  END AS payment_group
FROM (SELECT DISTINCT payment_type FROM `adm-project-olist.olist_raw.order_payments`)
UNION ALL
SELECT -1, 'unknown', 'Other';