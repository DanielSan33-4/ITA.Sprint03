-- SPRINT 3 Daniel Sánchez
-- Nivell 1
-- Exercici 2: Arquitectura de Dades (Lògica vs. Física)
CREATE OR REPLACE EXTERNAL TABLE sprint3-analytics-daniel-sanch.sprint3_bronze.transactions_raw
OPTIONS ( format = 'CSV', 
          uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'], 
          field_delimiter = ';');

CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.companies_raw
( company_id STRING,
  company_name STRING,
  phone STRING,
  email STRING,
  country STRING,
  website STRING)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
  skip_leading_rows = 1);

CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.american_users_raw
OPTIONS ( format = 'CSV', 
uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv']);

CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.european_users_raw
OPTIONS ( format = 'CSV', 
uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv']);

CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.credit_cards_raw
OPTIONS ( format = 'CSV', 
uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv']);

-- Exercici 4: Arquitectura i Rendiment. Materialització de Dades (Assistit per IA) 
	-- Materialització de Dades (Assistit per IA)
CREATE OR REPLACE TABLE `sprint3-analytics-daniel-sanch.sprint3_bronze.transactions_raw_native` AS
SELECT *
FROM `sprint3-analytics-daniel-sanch.sprint3_bronze.transactions_raw`;

	-- Auditoria de Costos 
SELECT id
FROM sprint3_bronze.transactions_raw;

SELECT id
FROM sprint3_bronze.transactions_raw_native;

	-- El perill del LIMIT 
SELECT id
FROM sprint3_bronze.transactions_raw
LIMIT 10;

SELECT id
FROM sprint3_bronze.transactions_raw_native
LIMIT 10;

-- Exercici 5: Adaptació de Sintaxi (Reporting) 
SELECT FORMAT_TIMESTAMP('%Y-%m-%d', timestamp) AS fecha_transaccion, SUM(amount) AS total_amount
FROM `sprint3_bronze.transactions_raw_native`
WHERE EXTRACT(YEAR FROM timestamp) = 2021
GROUP BY fecha_transaccion
ORDER BY total_amount DESC
LIMIT 5;

-- Exercici 6: Consultes Complexes 
SELECT companies_raw.company_name, companies_raw.country, transactions_raw_native.timestamp
FROM `sprint3-analytics-daniel-sanch.sprint3_bronze.transactions_raw_native` AS transactions_raw_native
JOIN `sprint3-analytics-daniel-sanch.sprint3_bronze.companies_raw` AS companies_raw 
    ON companies_raw.company_id = transactions_raw_native.business_id
WHERE transactions_raw_native.amount BETWEEN 100 AND 200
AND FORMAT_TIMESTAMP('%Y-%m-%d', timestamp) IN ('2015-04-29', '2018-07-20', '2024-03-20');

-- Nivell 2
-- Exercici 1: Neteja de Productes (Data Quality)  
CREATE OR REPLACE TABLE `sprint3_silver.products_clean` AS
SELECT 
  id AS product_id, 
  product_name AS name, 
  SAFE_CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id, 
  SAFE_CAST(REGEXP_REPLACE(CAST(price AS STRING), r'[^0-9.]', '') AS FLOAT64) AS price, 
  weight
FROM `sprint3_bronze.products_raw`;

-- Exercici 2: Creació de Transaccions Netes (Capa Silver) 
CREATE OR REPLACE TABLE sprint3_silver.transactions_clean AS 
SELECT 
  id AS transaction_id,
  IFNULL(SAFE_CAST(amount AS FLOAT64), 0) AS amount, 
  SAFE_CAST(lat AS FLOAT64) AS lat,
  SAFE_CAST(longitude AS FLOAT64) AS longitude,
  SAFE_CAST(timestamp AS TIMESTAMP) AS timestamp,
  ARRAY(
    SELECT SAFE_CAST(TRIM(product_id_str) AS INT64)
    FROM UNNEST(SPLIT(product_ids, ',')) AS product_id_str
  ) AS product_ids,
  business_id,
  user_id,
  card_id,
  declined
  FROM `sprint3-analytics-daniel-sanch.sprint3_bronze.transactions_raw_native`;
  
  -- Exercici 3: Unificació d'Usuaris (UNION) 
  CREATE OR REPLACE TABLE `sprint3_silver.users_combined` AS 
SELECT 
  id AS user_id, 
  'USA' AS origin, 
  * EXCEPT(id) 
FROM `sprint3_bronze.american_users_raw` 
UNION ALL 
SELECT 
  id AS user_id, 
  'EU' AS origin, 
  * EXCEPT(id) 
  FROM `sprint3_bronze.european_users_raw`;
  
  -- Exercici 4: Materialització de Companyies i Targetes de Crèdit 
  CREATE OR REPLACE TABLE `sprint3-analytics-daniel-sanch.sprint3_silver.credit_cards_clean` AS
SELECT *
FROM `sprint3-analytics-daniel-sanch.sprint3_bronze.credit_cards_raw`;

CREATE OR REPLACE TABLE `sprint3-analytics-daniel-sanch.sprint3_silver.companies_clean` AS
SELECT company_id AS id, * EXCEPT(company_id)
FROM `sprint3_bronze.companies_raw`;

-- Nivell 3
-- Exercici 1: La Vista de Màrqueting (Lògica de Negoci) 
CREATE VIEW `sprint3_gold.v_marketing_kpis` AS
SELECT c.company_name, c.phone, c.country, AVG(t.amount) AS mitjana_compra,CASE WHEN AVG(t.amount) > 260 THEN "Premium" ELSE "Standard" END AS client_tier
FROM `sprint3-analytics-daniel-sanch.sprint3_silver.transactions_clean` AS t
JOIN `sprint3-analytics-daniel-sanch.sprint3_silver.companies_clean` AS c ON t.business_id = c.id
GROUP BY c.company_name, c.phone, c.country;

-- Exercici 2: Rànquing de Productes (La Potència dels Arrays) 
CREATE OR REPLACE TABLE `sprint3-analytics-daniel-sanch.sprint3_gold.product_sales_ranking` AS
WITH trans_temporal AS (
  SELECT single_product_id
  FROM `sprint3-analytics-daniel-sanch.sprint3_silver.transactions_clean`,
  UNNEST(product_ids) AS single_product_id
)
SELECT p.product_id, p.name, p.price, p.weight, COUNT(tt.single_product_id) AS sales_count
FROM `sprint3-analytics-daniel-sanch.sprint3_silver.products_clean` AS p
LEFT JOIN trans_temporal tt ON p.product_id = tt.single_product_id 
GROUP BY p.product_id, p.name, p.price, p.weight
ORDER BY sales_count DESC;

-- Exercici 3: Exportació de Resultats 
SELECT * 
FROM `sprint3-analytics-daniel-sanch.sprint3_gold.product_sales_ranking`
ORDER BY sales_count DESC;




