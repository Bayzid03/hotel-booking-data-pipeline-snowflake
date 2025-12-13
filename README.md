# 🏨 Hotel Booking Data Pipeline on Snowflake

[![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)](https://www.snowflake.com/)
[![SQL](https://img.shields.io/badge/SQL-4479A1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.sql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

> **Production-grade ELT pipeline implementing medallion architecture (Bronze → Silver → Gold) for hotel booking analytics with automated data quality checks and business-ready aggregations.**

---

## 🎯 Project Overview

Built an end-to-end data pipeline on Snowflake to process hotel booking transactions across multiple properties and cities. The pipeline cleanses raw data, validates business rules, and produces 8 aggregated KPI tables for revenue analytics and customer insights.

**Key Achievements:**
- 🔧 Implemented **3-layer medallion architecture** for data maturity
- ✅ Applied **5+ data quality checks** (email validation, date logic, amount sanitization)
- 📊 Created **8 Gold-layer aggregations** for instant KPI reporting
- 🚀 Achieved **sub-second query performance** with pre-computed tables

---

## 🏗️ Architecture

```
CSV Files → Bronze Layer → Silver Layer → Gold Layer → Dashboards
            (Raw Staging)   (Cleansed)    (Aggregated)
```

| Layer | Purpose | Key Features |
|-------|---------|--------------|
| **Bronze** | Raw ingestion | All STRING columns, ON_ERROR='CONTINUE' |
| **Silver** | Cleansed data | Type casting, validation, text standardization |
| **Gold** | Analytics-ready | 8 pre-aggregated KPI tables + fact table |

---

## ✨ Key Features

### 🔍 Data Quality Checks
- Email validation with pattern matching
- Negative amount detection and correction
- Date logic validation (check-out ≥ check-in)
- Status typo fixes and normalization
- NULL handling with safe type casting

### 📊 Gold Layer Outputs

**8 Pre-Aggregated KPI Tables:**
1. **Daily Bookings & Revenue** - Trend analysis by check-in date
2. **Hotel City Sales** - Revenue by location
3. **Booking Status Analysis** - Confirmed/Cancelled/No-Show breakdown
4. **Room Type Performance** - Revenue, bookings, avg ticket
5. **City KPIs** - Bookings, revenue, stay nights, ADR
6. **Hotel Performance** - Property-level metrics with ADR
7. **Customer Value** - Top customers by revenue and lifetime bookings
8. **Stay Length Buckets** - Distribution (1-2, 3-5, 6-10, 11+ nights)

---

## 📐 Data Model

### Pipeline Flow
```
Bronze (Raw TEXT)
  ↓ Type casting, validation, standardization
Silver (Cleansed)
  ↓ Aggregations, derived metrics
Gold (Analytics-Ready)
  ├── HOTEL_BOOKINGS_GOLD (Fact Table)
  └── 8 KPI Tables (GOLD_AGG_*)
```

**Transformations Applied:**
- Text: `INITCAP()`, `TRIM()`, `LOWER()`
- Numbers: `TRY_TO_NUMBER()`, `ABS()`
- Dates: `TRY_TO_DATE()`, `DATEDIFF()`
- Business Logic: Status normalization, email validation

---

## 📊 Dashboard Visualizations

### 1. Revenue Overview Dashboard
![Revenue Dashboard](![Screenshot_11-12-2025_12122_app snowflake com](https://github.com/user-attachments/assets/bb63c59e-06ff-48e6-ae91-1964596eb703))

### 2. City Performance Analytics
![City Analytics](![Screenshot_11-12-2025_121219_app snowflake com](https://github.com/user-attachments/assets/bd24f1d3-dc20-40be-9c96-5547275ec539))

### 3.
![Screenshot_11-12-2025_121231_app snowflake com](https://github.com/user-attachments/assets/120587e6-fb00-4880-811e-6375d0a9f370)

---

## 🚀 Quick Start

### Prerequisites
- Snowflake account with database creation privileges
- CSV data files staged in Snowflake

### Setup
1. Clone the repository
2. Execute `hotel_booking.sql` in Snowflake
3. Upload CSV files to `HOTEL_BOOKING_STG` stage
4. Pipeline will automatically process: Bronze → Silver → Gold

---

## 📈 Results & Impact

### Performance Metrics
- ⚡ **Query Performance**: Sub-second aggregations on pre-computed Gold tables
- ✅ **Data Quality**: 100% validated records in Silver layer
- 📊 **Business Value**: 8 instant-access KPI tables for dashboards

### Technical Highlights
- Medallion architecture with clear separation of concerns
- Defensive programming with `TRY_*` functions for robustness
- Business logic centralized in Gold layer for consistency
- Reusable file formats and stages for scalability

---

## 📁 Project Structure

```
hotel-booking-data-pipeline-snowflake/
├── hotel_booking.sql          # Complete pipeline (Bronze → Silver → Gold)
├── data/                      # Sample CSV files (not included)
└── README.md
```

---

## 🎓 Skills Demonstrated

- **Cloud Data Warehousing**: Snowflake architecture and best practices
- **Data Quality**: Validation, cleansing, and error handling
- **SQL Engineering**: Advanced transformations, CTEs, window functions
- **Data Modeling**: Medallion architecture implementation
- **Analytics Engineering**: Pre-aggregated KPI design for BI tools

---

## 📄 License

This project is licensed under the MIT License.

---

<div align="center">

**⭐ If you found this project helpful, please star the repo!**

Built with ❤️ using Snowflake & SQL

</div>
