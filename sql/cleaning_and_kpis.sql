-- ============================================================
-- PROJET : Analyse des ventes retail & tableau de bord exécutif
-- Fichier : cleaning_and_kpis.sql
-- Base : superstore.db (SQLite)
-- ============================================================


-- ============================================================
-- 1. DIAGNOSTIC DES DONNEES BRUTES (table sales_raw)
-- ============================================================

-- Nombre total de lignes
SELECT COUNT(*) AS total_lignes FROM sales_raw;

-- Doublons sur Row ID
SELECT "Row ID", COUNT(*) AS occurrences
FROM sales_raw
GROUP BY "Row ID"
HAVING COUNT(*) > 1;

-- Valeurs manquantes sur les colonnes clés
SELECT
  SUM(CASE WHEN "Order Date" IS NULL OR "Order Date" = '' THEN 1 ELSE 0 END) AS order_date_vides,
  SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END) AS sales_vides,
  SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS profit_vides,
  SUM(CASE WHEN Region IS NULL OR Region = '' THEN 1 ELSE 0 END) AS region_vides,
  SUM(CASE WHEN Category IS NULL OR Category = '' THEN 1 ELSE 0 END) AS category_vides
FROM sales_raw;

-- Ventes négatives ou nulles
SELECT COUNT(*) AS ventes_negatives_ou_nulles
FROM sales_raw
WHERE Sales <= 0;

-- Quantités négatives ou nulles
SELECT COUNT(*) AS quantites_negatives_ou_nulles
FROM sales_raw
WHERE Quantity <= 0;

-- Valeurs distinctes de Region (contrôle qualité : fautes de frappe, casse)
SELECT DISTINCT Region FROM sales_raw;

-- Valeurs distinctes de Category (contrôle qualité)
SELECT DISTINCT Category FROM sales_raw;


-- ============================================================
-- 2. CREATION DE LA TABLE NETTOYEE ET ENRICHIE : sales_clean
--    (les dates sources sont au format texte M/D/Y, ex: 11/8/2016,
--    non reconnu nativement par DATE() en SQLite -> parsing manuel)
-- ============================================================

DROP TABLE IF EXISTS sales_clean;

CREATE TABLE sales_clean AS
WITH parsed AS (
  SELECT *,
    CAST(substr("Order Date", 1, instr("Order Date", '/') - 1) AS INTEGER) AS om,
    CAST(substr(substr("Order Date", instr("Order Date", '/') + 1),
                1,
                instr(substr("Order Date", instr("Order Date", '/') + 1), '/') - 1) AS INTEGER) AS od,
    CAST(substr("Order Date",
                instr("Order Date", '/') + 1 + instr(substr("Order Date", instr("Order Date", '/') + 1), '/')) AS INTEGER) AS oy,
    CAST(substr("Ship Date", 1, instr("Ship Date", '/') - 1) AS INTEGER) AS sm,
    CAST(substr(substr("Ship Date", instr("Ship Date", '/') + 1),
                1,
                instr(substr("Ship Date", instr("Ship Date", '/') + 1), '/') - 1) AS INTEGER) AS sd,
    CAST(substr("Ship Date",
                instr("Ship Date", '/') + 1 + instr(substr("Ship Date", instr("Ship Date", '/') + 1), '/')) AS INTEGER) AS sy
  FROM sales_raw
)
SELECT
  "Row ID"        AS row_id,
  "Order ID"      AS order_id,
  printf('%04d-%02d-%02d', oy, om, od) AS order_date,
  printf('%04d-%02d-%02d', sy, sm, sd) AS ship_date,
  "Ship Mode"     AS ship_mode,
  "Customer ID"   AS customer_id,
  "Customer Name" AS customer_name,
  Segment         AS segment,
  Region          AS region,
  State           AS state,
  City            AS city,
  Category        AS category,
  "Sub-Category"  AS sub_category,
  "Product Name"  AS product_name,
  Sales           AS sales,
  Quantity        AS quantity,
  Discount        AS discount,
  Profit          AS profit,
  ROUND(Profit * 1.0 / Sales, 4) AS profit_margin,
  oy AS order_year,
  printf('%02d', om) AS order_month,
  CASE
    WHEN om BETWEEN 1 AND 3 THEN 'Q1'
    WHEN om BETWEEN 4 AND 6 THEN 'Q2'
    WHEN om BETWEEN 7 AND 9 THEN 'Q3'
    ELSE 'Q4'
  END AS order_quarter
FROM parsed;


-- ============================================================
-- 3. VERIFICATION POST-TRANSFORMATION
-- ============================================================

-- Aperçu des dates converties
SELECT order_date, ship_date, order_year, order_month, order_quarter
FROM sales_clean
LIMIT 5;

-- Contrôle : aucune ligne perdue par rapport à sales_raw
SELECT COUNT(*) AS total_clean FROM sales_clean;

-- Contrôle : aucune date mal convertie
SELECT COUNT(*) AS dates_invalides
FROM sales_clean
WHERE order_date NOT LIKE '____-__-__' OR ship_date NOT LIKE '____-__-__';


-- ============================================================
-- 4. KPIs (table sales_clean)
-- ============================================================

-- Chiffre d'affaires, marge et panier moyen globaux
SELECT
  ROUND(SUM(sales), 2) AS ca_total,
  ROUND(SUM(profit), 2) AS profit_total,
  ROUND(SUM(profit) * 1.0 / SUM(sales), 4) AS marge_globale,
  ROUND(AVG(sales), 2) AS panier_moyen,
  COUNT(DISTINCT order_id) AS nb_commandes
FROM sales_clean;

-- Top 10 produits par chiffre d'affaires
SELECT
  product_name,
  ROUND(SUM(sales), 2) AS ca,
  ROUND(SUM(profit), 2) AS profit
FROM sales_clean
GROUP BY product_name
ORDER BY ca DESC
LIMIT 10;

-- Performance par région
SELECT
  region,
  ROUND(SUM(sales), 2) AS ca,
  ROUND(SUM(profit), 2) AS profit,
  ROUND(SUM(profit) * 1.0 / SUM(sales), 4) AS marge
FROM sales_clean
GROUP BY region
ORDER BY ca DESC;

-- Évolution mensuelle des ventes
SELECT
  order_year,
  order_month,
  ROUND(SUM(sales), 2) AS ca_mensuel
FROM sales_clean
GROUP BY order_year, order_month
ORDER BY order_year, order_month;

-- Catégories/sous-catégories les moins rentables
SELECT
  category,
  sub_category,
  ROUND(SUM(sales), 2) AS ca,
  ROUND(SUM(profit), 2) AS profit,
  ROUND(SUM(profit) * 1.0 / SUM(sales), 4) AS marge
FROM sales_clean
GROUP BY category, sub_category
ORDER BY marge ASC
LIMIT 5;