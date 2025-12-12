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
