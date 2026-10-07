CREATE OR REPLACE TABLE `adm-project-olist.olist_dw.dim_product` AS
WITH trans AS (
  SELECT
    string_field_0 AS product_category_name,
    string_field_1 AS product_category_name_english
  FROM `adm-project-olist.olist_raw.product_category_name_translation`
  WHERE string_field_0 != 'product_category_name'   -- bỏ dòng tiêu đề bị đọc thành dữ liệu
),
base AS (
  SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category
  FROM `adm-project-olist.olist_raw.products` p
  LEFT JOIN trans t
    ON t.product_category_name = p.product_category_name
)
SELECT
  ROW_NUMBER() OVER (ORDER BY product_id) AS product_key,
  product_id,
  category,
  CASE
    WHEN category IN ('computers','computers_accessories','pc_gamer','electronics','telephony','fixed_telephony',
                      'tablets_printing_image','audio','consoles_games','cine_photo','dvds_blu_ray','cds_dvds_musicals','music')
         THEN 'Electronics'
    WHEN category IN ('bed_bath_table','furniture_decor','furniture_living_room','furniture_bedroom','furniture_mattress_and_upholstery',
                      'office_furniture','kitchen_dining_laundry_garden_furniture','housewares','home_appliances','home_appliances_2',
                      'home_comfort_2','home_confort','small_appliances','small_appliances_home_oven_and_coffee',
                      'portable_kitchen_food_processors','la_cuisine','air_conditioning','garden_tools','flowers')
         THEN 'Home'
    WHEN category IN ('fashion_bags_accessories','fashion_shoes','fashion_male_clothing','fashio_female_clothing','fashion_underwear_beach',
                      'fashion_sport','fashion_childrens_clothes','watches_gifts','luggage_accessories')
         THEN 'Fashion'
    WHEN category IN ('health_beauty','perfumery','baby','diapers_and_hygiene')
         THEN 'Health Beauty Baby'
    WHEN category IN ('sports_leisure','toys','musical_instruments','party_supplies','christmas_supplies','cool_stuff','art','arts_and_craftmanship','pet_shop')
         THEN 'Leisure'
    WHEN category IN ('books_general_interest','books_technical','books_imported','stationery')
         THEN 'Books Stationery'
    WHEN category IN ('food','food_drink','drinks','market_place')
         THEN 'Food Drink'
    WHEN category IN ('construction_tools_construction','construction_tools_lights','construction_tools_safety','costruction_tools_garden',
                      'costruction_tools_tools','home_construction','agro_industry_and_commerce','industry_commerce_and_business',
                      'security_and_services','signaling_and_security')
         THEN 'Industry'
    WHEN category = 'auto' THEN 'Auto'
    ELSE 'Other'
  END AS category_group
FROM base;