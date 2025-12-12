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
