------------------------------------------------------------------------
-- ЧАСТИНА 1: Робота зі складними структурами даних (ARRAY & STRUCT)
------------------------------------------------------------------------

-- Завдання 1: Перегляд полів REPEATED (масивів) для одного активного користувача з валідними товарами
WITH one_user AS (
  SELECT 
    user_pseudo_id,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`,
  UNNEST(items) AS i
  WHERE i.item_name IS NOT NULL AND i.item_name <> '(not set)'
  LIMIT 1
)
SELECT 
  ga4.user_pseudo_id,
  TIMESTAMP_MICROS(ga4.event_timestamp) AS event_timestamp,
  ga4.event_name,
  ga4.event_params,
  ga4.user_properties,
  ga4.items 
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131` AS ga4
RIGHT JOIN one_user AS o 
  ON o.user_pseudo_id = ga4.user_pseudo_id 
  AND o.event_timestamp = TIMESTAMP_MICROS(ga4.event_timestamp);


-- Завдання 2: Визначення розміру масивів для параметрів подій, властивостей користувача та товарів
WITH one_user AS (
  SELECT 
    user_pseudo_id,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`,
  UNNEST(items) AS i
  WHERE i.item_name IS NOT NULL AND i.item_name <> '(not set)'
  LIMIT 1
)
SELECT 
  ga4.user_pseudo_id,
  TIMESTAMP_MICROS(ga4.event_timestamp) AS event_timestamp,
  ga4.event_name,
  ga4.event_params,
  ga4.user_properties,
  ga4.items,
  ARRAY_LENGTH(ga4.event_params) AS nb_event,
  ARRAY_LENGTH(ga4.user_properties) AS nb_user_properties,
  ARRAY_LENGTH(ga4.items) AS nb_user_items
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131` AS ga4
RIGHT JOIN one_user AS o 
  ON o.user_pseudo_id = ga4.user_pseudo_id 
  AND o.event_timestamp = TIMESTAMP_MICROS(ga4.event_timestamp);


-- Завдання 3: Розгортання (UNNEST) масиву event_params для конкретного рядка та користувача
WITH one_user AS (
  SELECT 
    user_pseudo_id,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`,
  UNNEST(items) AS i
  WHERE i.item_name IS NOT NULL AND i.item_name <> '(not set)'
  LIMIT 1
)
SELECT 
  ga4.user_pseudo_id,
  TIMESTAMP_MICROS(ga4.event_timestamp) AS event_timestamp,
  ga4.event_name,
  ep.key,
  ep.value.string_value,
  ep.value.int_value,
  ep.value.double_value
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131` AS ga4
RIGHT JOIN one_user AS o 
  ON o.user_pseudo_id = ga4.user_pseudo_id 
  AND o.event_timestamp = TIMESTAMP_MICROS(ga4.event_timestamp),
  UNNEST(event_params) AS ep
ORDER BY ep.key ASC;


-- Завдання 4: Аналіз частоти параметрів подій за весь 2021 рік
SELECT 
  ep.key,
  COUNT(ep.key) AS total_params
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_2021*`,
UNNEST(event_params) AS ep
GROUP BY 1
ORDER BY total_params DESC;


------------------------------------------------------------------------
-- ЧАСТИНА 2: Розрахунок метрик ефективності товарів та E-commerce
------------------------------------------------------------------------

-- Завдання 5: Розгортання масиву items для отримання детальної інформації про товари
SELECT 
  ga4.user_pseudo_id,
  TIMESTAMP_MICROS(ga4.event_timestamp) AS event_timestamp,
  i.item_id,
  i.item_name,
  i.item_category,
  i.price,
  i.quantity
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131` AS ga4,
UNNEST(items) AS i
LIMIT 50;


-- Завдання 6: Зведена таблиця ефективності товарів (кількість подій, кількість проданого товару та дохід)
SELECT 
  i.item_id, 
  i.item_name,
  COUNT(*) AS count_events,
  SUM(i.quantity) AS sum_quantity,
  SUM(i.price * i.quantity) AS total_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`,
UNNEST(items) AS i
GROUP BY 1, 2
ORDER BY total_revenue DESC;


-- Завдання 7: Фільтрація подій за значенням усередині масиву items (тільки категорія 'Apparel')
SELECT DISTINCT 
  event_name
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
WHERE EXISTS (
  SELECT 1 
  FROM UNNEST(items) AS i 
  WHERE i.item_category = 'Apparel'
);


------------------------------------------------------------------------
-- ЧАСТИНА 3: Сегментація користувачів та просунуті аналітичні віконні функції
------------------------------------------------------------------------

-- Завдання 8: Робота з партиціями через суфікси таблиць для аналізу щоденної активності користувачів
SELECT 
  PARSE_DATE('%Y%m%d', _TABLE_SUFFIX) AS event_date,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS count_users,
  COUNTIF(event_name = 'purchase') AS count_purchase
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY 1
ORDER BY event_date ASC;


-- Завдання 9: Ранжування ТОП-20 VIP-користувачів за витратами за допомогою різних віконних функцій
SELECT
  user_pseudo_id,
  SUM(i.price * i.quantity) AS total_revenue,
  RANK() OVER (ORDER BY SUM(i.price * i.quantity) DESC) AS rank_revenue,
  DENSE_RANK() OVER (ORDER BY SUM(i.price * i.quantity) DESC) AS dense_rank_revenue,
  ROW_NUMBER() OVER (ORDER BY SUM(i.price * i.quantity) DESC) AS rn_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
UNNEST(items) AS i
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 20;


-- Завдання 10: Аналіз сесій для визначення події, яка найчастіше є стартовою (тригером початку сесії)
WITH ga_session_user AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_timestamp,
    (
      SELECT value.int_value 
      FROM UNNEST(event_params) AS e 
      WHERE key = 'ga_session_id'
    ) AS ga_session_id 
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
),
rn_event AS (
  SELECT 
    user_pseudo_id,
    event_name,
    event_timestamp,
    ga_session_id,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id, ga_session_id 
      ORDER BY event_timestamp ASC
    ) AS rn
  FROM ga_session_user
)
SELECT 
  event_name
FROM rn_event
WHERE rn = 1
GROUP BY 1
ORDER BY COUNT(*) DESC 
LIMIT 1;
