CREATE DATABASE IF NOT EXISTS HOTEL_BOOKING_DB;

-- Define reusable CSV file format for hotel booking pipeline.
-- Ensures consistent parsing (quoted fields, header skip, NULL handling) 
-- across all COPY INTO operations in Snowflake.
CREATE OR REPLACE FILE FORMAT HOTEL_CSV_FORMAT
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '');

-- Create stage for hotel booking files with reusable CSV format
CREATE OR REPLACE STAGE HOTEL_BOOKING_STG
    FILE_FORMAT = HOTEL_CSV_FORMAT;

-- List files in your stage
LIST @HOTEL_BOOKING_STG;

-- Create Table HOTEL_BOOKING_BRONZE
CREATE TABLE HOTEL_BOOKING_BRONZE (
    booking_id STRING,
    hotel_id STRING,
    hotel_city STRING,
    customer_id STRING,
    customer_name STRING,
    customer_email STRING,
    check_in_date STRING,
    check_out_date STRING,
    room_type STRING,
    num_guests STRING,
    total_amount STRING,
    currency STRING,
    booking_status STRING
);

-- Load raw hotel booking CSV files from stage into Bronze layer.
-- Applies reusable file format and continues on row-level errors for robust ingestion.
COPY INTO HOTEL_BOOKING_BRONZE
FROM @HOTEL_BOOKING_STG
FILE_FORMAT = (FORMAT_NAME = HOTEL_CSV_FORMAT)
ON_ERROR = 'CONTINUE';

SELECT * FROM HOTEL_BOOKING_BRONZE LIMIT 20;

---------------------------------------------------------
-- SILVER LAYER
---------------------------------------------------------

-- Create Table HOTEL_BOOKINGS_SILVER
CREATE TABLE HOTEL_BOOKINGS_SILVER (
    booking_id VARCHAR,
    hotel_id VARCHAR,
    hotel_city VARCHAR,
    customer_id VARCHAR,
    customer_name VARCHAR,
    customer_email VARCHAR,
    check_in_date DATE,
    check_out_date DATE,
    room_type VARCHAR,
    num_guests INTEGER,
    total_amount FLOAT,
    currency VARCHAR,
    booking_status VARCHAR
);

-- Data quality check.
-- Identify invalid or missing customer emails in Bronze layer
SELECT customer_email
FROM HOTEL_BOOKING_BRONZE
WHERE NOT (customer_email LIKE '%@%.%')
    OR customer_email IS NULL

-- Detect negative booking amounts (invalid pricing entries)
SELECT total_amount
FROM HOTEL_BOOKING_BRONZE
WHERE TRY_TO_NUMBER(total_amount) < 0;

-- Flag bookings where check-out date is earlier than check-in date
SELECT check_in_date, check_out_date
FROM HOTEL_BOOKING_BRONZE
WHERE TRY_TO_DATE(check_out_date) < TRY_TO_DATE(check_in_date);

SELECT DISTINCT booking_status from HOTEL_BOOKING_BRONZE;

-- Insert cleaned records from Bronze into Silver layer
-- Standardizes text (trim, proper case), validates emails, converts dates/numbers,
-- fixes negative amounts, corrects status typos, and filters invalid date ranges.
INSERT INTO HOTEL_BOOKINGS_SILVER
SELECT
    booking_id,
    hotel_id,
    INITCAP(TRIM(hotel_city)) AS hotel_city,           -- Clean city names
    customer_id,
    INITCAP(TRIM(customer_name)) AS customer_name,     -- Proper case for names
    CASE                                               -- Validate and normalize emails
        WHEN customer_email LIKE '%@%.%' THEN LOWER(TRIM(customer_email))
        ELSE NULL
    END AS customer_email,
    TRY_TO_DATE(NULLIF(check_in_date, '')) AS check_in_date,   -- Convert to DATE
    TRY_TO_DATE(NULLIF(check_out_date, '')) AS check_out_date, -- Convert to DATE
    room_type,
    num_guests,
    ABS(TRY_TO_NUMBER(total_amount)) AS total_amount,  -- Ensure positive numeric amount
    currency,
    CASE                                               -- Fix common status typos
        WHEN LOWER(booking_status) IN ('confirmeeed','confirmd') THEN 'Confirmed'
        ELSE booking_status
    END AS booking_status
FROM HOTEL_BOOKING_BRONZE
WHERE
    TRY_TO_DATE(check_in_date) IS NOT NULL             -- Only valid dates
    AND TRY_TO_DATE(check_out_date) IS NOT NULL
    AND TRY_TO_DATE(check_out_date) >= TRY_TO_DATE(check_in_date); -- Logical date range

SELECT * FROM HOTEL_BOOKINGS_SILVER LIMIT 20;

-------------------------------------------------
-- GOLD LAYER
-------------------------------------------------

-- daily bookings and revenue aggregated by check-in date
CREATE TABLE GOLD_AGG_DAILY_BOOKING AS
SELECT
    check_in_date AS date,
    COUNT(*) AS total_booking,
    SUM(total_amount) AS total_revenue
FROM HOTEL_BOOKINGS_SILVER
GROUP BY check_in_date
ORDER BY date;

-- total revenue aggregated by hotel city
CREATE TABLE GOLD_AGG_HOTEL_CITY_SALES AS
SELECT
    hotel_city,
    SUM(total_amount) AS total_revenue
FROM HOTEL_BOOKINGS_SILVER
GROUP BY hotel_city
ORDER BY total_revenue DESC;

-- bookings and revenue by booking status
CREATE TABLE GOLD_AGG_BOOKING_STATUS AS
SELECT
  booking_status,
  COUNT(*) AS total_bookings,
  SUM(total_amount) AS total_revenue
FROM HOTEL_BOOKINGS_SILVER
GROUP BY booking_status
ORDER BY total_revenue DESC;

-- room-type performance (bookings, revenue, average ticket)
CREATE TABLE GOLD_AGG_ROOM_TYPE_PERFORMANCE AS
SELECT
  room_type,
  COUNT(*) AS total_bookings,
  SUM(total_amount) AS total_revenue,
  AVG(total_amount) AS avg_amount
FROM HOTEL_BOOKINGS_SILVER
GROUP BY room_type
ORDER BY total_revenue DESC;

-- city KPIs with currency safety (bookings, revenue, stay nights, ADR)
CREATE TABLE GOLD_AGG_CITY_KPIS AS
SELECT
  hotel_city,
  currency,
  COUNT(*) AS total_bookings,
  SUM(total_amount) AS total_revenue,
  SUM(DATEDIFF('day', check_in_date, check_out_date)) AS total_stay_nights,
  ROUND(
    SUM(total_amount) / NULLIF(SUM(DATEDIFF('day', check_in_date, check_out_date)), 0),
    2
  ) AS adr
FROM HOTEL_BOOKINGS_SILVER
GROUP BY hotel_city, currency
ORDER BY total_revenue DESC;

-- hotel-level performance (bookings, revenue, stay nights, ADR)
CREATE TABLE GOLD_AGG_HOTEL_PERFORMANCE AS
SELECT
  hotel_id,
  hotel_city,
  currency,
  COUNT(*) AS total_bookings,
  SUM(total_amount) AS total_revenue,
  SUM(DATEDIFF('day', check_in_date, check_out_date)) AS total_stay_nights,
  ROUND(
    SUM(total_amount) / NULLIF(SUM(DATEDIFF('day', check_in_date, check_out_date)), 0),
    2
  ) AS adr
FROM HOTEL_BOOKINGS_SILVER
GROUP BY hotel_id, hotel_city, currency
ORDER BY total_revenue DESC;

-- top customers by revenue and bookings
CREATE TABLE GOLD_AGG_CUSTOMER_VALUE AS
SELECT
  customer_id,
  INITCAP(customer_name) AS customer_name,
  COUNT(*) AS total_bookings,
  SUM(total_amount) AS total_revenue,
  MIN(check_in_date) AS first_stay,
  MAX(check_out_date) AS last_stay
FROM HOTEL_BOOKINGS_SILVER
GROUP BY customer_id, customer_name
ORDER BY total_revenue DESC;

-- stay-length distribution buckets (nights)
CREATE TABLE GOLD_AGG_STAY_LENGTH_BUCKETS AS
WITH stays AS (
  SELECT
    booking_id,
    DATEDIFF('day', check_in_date, check_out_date) AS nights
  FROM HOTEL_BOOKINGS_SILVER
)
SELECT
  CASE
    WHEN nights IS NULL OR nights <= 0 THEN '0 or invalid'
    WHEN nights BETWEEN 1 AND 2 THEN '1-2'
    WHEN nights BETWEEN 3 AND 5 THEN '3-5'
    WHEN nights BETWEEN 6 AND 10 THEN '6-10'
    ELSE '11+'
  END AS stay_length_bucket,
  COUNT(*) AS bookings
FROM stays
GROUP BY stay_length_bucket
ORDER BY bookings DESC;

SELECT * FROM GOLD_AGG_DAILY_BOOKING LIMIT 10;

SELECT * FROM GOLD_AGG_HOTEL_CITY_SALES LIMIT 10;

SELECT * FROM GOLD_AGG_BOOKING_STATUS LIMIT 10;

SELECT * FROM GOLD_AGG_ROOM_TYPE_PERFORMANCE LIMIT 10;

SELECT * FROM GOLD_AGG_CITY_KPIS LIMIT 10;

SELECT * FROM GOLD_AGG_HOTEL_PERFORMANCE LIMIT 10;

SELECT * FROM GOLD_AGG_CUSTOMER_VALUE LIMIT 10;

SELECT * FROM GOLD_AGG_STAY_LENGTH_BUCKETS LIMIT 10;


-- Gold table: clean, business-ready hotel bookings fact table
-- Provides standardized schema for dashboards and KPI calculations
CREATE TABLE HOTEL_BOOKINGS_GOLD AS
SELECT
    booking_id,
    hotel_id,
    INITCAP(hotel_city) AS hotel_city,          -- standardized city names
    customer_id,
    INITCAP(customer_name) AS customer_name,    -- proper case names
    LOWER(customer_email) AS customer_email,    -- normalized emails
    check_in_date,
    check_out_date,
    room_type,
    num_guests,
    ROUND(total_amount, 2) AS total_amount,     -- rounded numeric amounts
    currency,
    CASE                                         -- normalized booking status
        WHEN LOWER(booking_status) IN ('confirmed','confirmeeed','confirmd') THEN 'Confirmed'
        WHEN LOWER(booking_status) = 'cancelled' THEN 'Cancelled'
        WHEN LOWER(booking_status) = 'no-show'   THEN 'No-Show'
        ELSE INITCAP(booking_status)
    END AS booking_status,
    DATEDIFF('day', check_in_date, check_out_date) AS stay_nights -- derived metric
FROM HOTEL_BOOKINGS_SILVER
WHERE
    check_in_date IS NOT NULL
    AND check_out_date IS NOT NULL
    AND check_out_date >= check_in_date;


SELECT * FROM HOTEL_BOOKINGS_GOLD LIMIT 10;
