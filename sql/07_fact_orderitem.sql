CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.fact_orderitem` AS
WITH ord AS (
  SELECT
    order_id,
    customer_id,
    order_status,
    DATE(SAFE_CAST(order_purchase_timestamp     AS TIMESTAMP)) AS purchase_date,
    DATE(SAFE_CAST(order_delivered_customer_date AS TIMESTAMP)) AS delivered_date,
    DATE(SAFE_CAST(order_estimated_delivery_date AS TIMESTAMP)) AS estimated_date
  FROM `adm-project-olist.olist_raw.orders`
),
pay AS (   -- mỗi đơn lấy loại thanh toán có số tiền lớn nhất
  SELECT order_id,
         ARRAY_AGG(payment_type ORDER BY val DESC LIMIT 1)[OFFSET(0)] AS payment_type
  FROM (
    SELECT order_id, payment_type, SUM(payment_value) AS val
    FROM `adm-project-olist.olist_raw.order_payments`
    GROUP BY order_id, payment_type
  )
  GROUP BY order_id
),
rev AS (   -- mỗi đơn lấy điểm đánh giá trung bình
  SELECT order_id, AVG(review_score) AS review_score
  FROM `adm-project-olist.olist_raw.order_reviews`
  GROUP BY order_id
)
SELECT
  i.order_id,
  i.order_item_id,

  COALESCE(CAST(FORMAT_DATE('%Y%m%d', o.purchase_date)  AS INT64), -1) AS purchase_date_key,
  COALESCE(CAST(FORMAT_DATE('%Y%m%d', o.delivered_date) AS INT64), -1) AS delivered_date_key,
  COALESCE(CAST(FORMAT_DATE('%Y%m%d', o.estimated_date) AS INT64), -1) AS estimated_date_key,

  dc.customer_key,
  ds.seller_key,
  dp.product_key,
  st.status_key,
  COALESCE(dpay.payment_key, -1) AS payment_key,

  i.price,
  i.freight_value,
  i.price + i.freight_value                                  AS item_total,
  DATE_DIFF(o.delivered_date, o.purchase_date, DAY)          AS delivery_days,
  DATE_DIFF(o.delivered_date, o.estimated_date, DAY)         AS delay_days,
  CASE WHEN o.delivered_date IS NULL THEN NULL
       WHEN o.delivered_date > o.estimated_date THEN 1 ELSE 0 END AS is_late,
  r.review_score
FROM `adm-project-olist.olist_raw.order_items` i
JOIN ord o                                              ON o.order_id = i.order_id
JOIN `adm-project-olist.olist_raw.customers` c          ON c.customer_id = o.customer_id
LEFT JOIN `adm-project-olist.olist_dw.dim_customer`    dc  ON dc.customer_unique_id = c.customer_unique_id
LEFT JOIN `adm-project-olist.olist_dw.dim_seller`      ds  ON ds.seller_id = i.seller_id
LEFT JOIN `adm-project-olist.olist_dw.dim_product`     dp  ON dp.product_id = i.product_id
LEFT JOIN `adm-project-olist.olist_dw.dim_orderstatus` st  ON st.order_status = o.order_status
LEFT JOIN pay                                          ON pay.order_id = i.order_id
LEFT JOIN `adm-project-olist.olist_dw.dim_payment`     dpay ON dpay.payment_type = pay.payment_type
LEFT JOIN rev r                                        ON r.order_id = i.order_id;