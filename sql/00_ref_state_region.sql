CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.ref_state_region` AS
SELECT * FROM UNNEST([
  STRUCT('AC' AS state, 'North' AS region), ('AP','North'), ('AM','North'), ('PA','North'), ('RO','North'), ('RR','North'), ('TO','North'),
  ('AL','Northeast'), ('BA','Northeast'), ('CE','Northeast'), ('MA','Northeast'), ('PB','Northeast'),
  ('PE','Northeast'), ('PI','Northeast'), ('RN','Northeast'), ('SE','Northeast'),
  ('DF','Central-West'), ('GO','Central-West'), ('MT','Central-West'), ('MS','Central-West'),
  ('ES','Southeast'), ('MG','Southeast'), ('RJ','Southeast'), ('SP','Southeast'),
  ('PR','South'), ('RS','South'), ('SC','South')
]);