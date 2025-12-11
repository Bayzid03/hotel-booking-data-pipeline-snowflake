# hotel-booking-data-pipeline-snowflake
End-to-end Snowflake-native hotel booking pipeline using Medallion Architecture (Bronze → Silver → Gold). Includes raw CSV ingestion via stages, SQL-based cleaning/validation (emails, dates, pricing, status), incremental loads, SCD2 dimensions, and Snowsight dashboards with KPIs (ADR, RevPAR, occupancy, cancellations).
