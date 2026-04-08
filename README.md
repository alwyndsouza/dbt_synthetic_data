# dbt Synthetic Data

Synthetic star-schema data generator for **dbt + DuckDB**. Generates 7 Parquet files (~500 MB) with 50K–5M rows each.

This project demonstrates using **Altimate Code** (AI data engineering agent) to automatically build dbt models from a requirements prompt.

## Quick Start

```bash
# Clone and setup
git clone https://github.com/alwyndsouza/dbt_synthetic_data.git
cd dbt_synthetic_data

# Full setup: uv environment, dbt packages, and synthetic data
make setup
```

This generates:
```
data/raw/
├── dim_users.parquet           (50K rows)
├── dim_products.parquet        (200 rows)
├── dim_locations.parquet       (500 rows)
├── dim_devices.parquet         (100 rows)
├── fact_transactions.parquet   (1M rows)
├── fact_sessions.parquet       (500K rows)
└── fact_events.parquet         (5M rows)
```

## Using Altimate Code to Build dbt Models

This project demonstrates an AI-driven workflow where **Altimate Code** reads your requirements from a prompt file and automatically builds all dbt models.

### Step 1: Generate Synthetic Data

```bash
make data
```

### Step 2: Review the Prompt

The requirements for building the dbt models are stored in `PROMPT.md`. This file contains:

- **Schema definitions** - Dimension and fact tables with columns
- **Model requirements** - 5 marts + 5 semantic models
- **Metrics to create** - Revenue, engagement, user, product, time-based
- **Business logic** - Segmentation, scoring, funnel analysis

### Step 3: Run Altimate Code with the Prompt

Load the prompt into Altimate Code and provide this instruction:

```
Read the PROMPT.md file and build all the dbt models described in it.
Follow the staging → intermediate → marts layer structure.
Create schema.yml files for each model with tests and descriptions.
After building, verify row counts match expectations.
```

Altimate Code will:
1. ✅ Read the schema from parquet files
2. ✅ Create staging models for all 7 tables
3. ✅ Create intermediate models with joins
4. ✅ Build 10 mart models with all calculated metrics
5. ✅ Add schema.yml with tests (unique, not_null)
6. ✅ Run `dbt build` and verify results

### Step 4: Verify the Models

```bash
# Run all models and tests
dbt build

# Check row counts
duckdb dbt_synthetic_data.duckdb -c "
SELECT 'mart_user_analytics' as model, COUNT(*) as rows FROM mart_user_analytics
UNION ALL SELECT 'mart_product_performance', COUNT(*) FROM mart_product_performance
UNION ALL SELECT 'mart_session_analytics', COUNT(*) FROM mart_session_analytics
UNION ALL SELECT 'mart_transaction_summary', COUNT(*) FROM mart_transaction_summary
UNION ALL SELECT 'mart_daily_metrics', COUNT(*) FROM mart_daily_metrics
UNION ALL SELECT 'mart_enriched_users', COUNT(*) FROM mart_enriched_users
UNION ALL SELECT 'mart_enriched_products', COUNT(*) FROM mart_enriched_products
UNION ALL SELECT 'mart_enriched_sessions', COUNT(*) FROM mart_enriched_sessions
UNION ALL SELECT 'mart_geographic_performance', COUNT(*) FROM mart_geographic_performance
UNION ALL SELECT 'mart_funnel_analytics', COUNT(*) FROM mart_funnel_analytics
"
```

## Make Commands

```bash
make env-setup    # Setup uv environment and dbt packages
make data         # Generate synthetic Parquet files
make install      # Create uv environment and install dependencies
make dbt-deps     # Install dbt packages
make setup        # Full setup (env + packages + data)
make clean        # Remove data and dbt artifacts
make help         # Show all commands
```

## Project Files

- `PROMPT.md` - Requirements prompt for Altimate Code
- `generate_data.py` - Data generation script
- `dbt_project.yml` - dbt project config
- `profiles.yml` - DuckDB connection settings
- `packages.yml` - dbt package dependencies
- `models/staging/sources.yml` - External Parquet table definitions

## Using with dbt

Query Parquet files directly in your models:

```sql
select * from read_parquet('data/raw/dim_users.parquet')
```

Sources are documented in `models/staging/sources.yml` for dbt's source freshness checks.

## Schema Overview

### Dimension Tables

| Table           | Rows    | Description                          |
|-----------------|---------|--------------------------------------|
| `dim_users`     | 50,000  | Users with tier, signup date, locale |
| `dim_products`  | 200     | Products with category and price     |
| `dim_locations` | 500     | Locations with country and region    |
| `dim_devices`   | 100     | Devices with type, OS, and browser   |

### Fact Tables

| Table                | Rows       | Description                         |
|----------------------|------------|-------------------------------------|
| `fact_transactions`  | 1,000,000  | Purchases with amount and status    |
| `fact_sessions`      | 500,000    | User sessions with duration         |
| `fact_events`        | 5,000,000  | Granular user interaction events    |

## Built Models

| Model | Rows | Purpose |
|-------|------|---------|
| `mart_user_analytics` | 50,000 | User-level metrics with LTV, engagement, segment |
| `mart_product_performance` | 200 | Product sales, revenue, performance tier |
| `mart_session_analytics` | 500,000 | Session metrics with quality scores |
| `mart_transaction_summary` | 1,000,000 | Transaction-level with full context |
| `mart_daily_metrics` | 1,559 | Daily KPIs with moving averages |
| `mart_enriched_users` | 50,000 | Semantic user model with RFM segments |
| `mart_enriched_products` | 200 | Product performance with rankings |
| `mart_enriched_sessions` | 500,000 | Enriched session with quality scoring |
| `mart_geographic_performance` | 500 | Regional revenue analytics |
| `mart_funnel_analytics` | 50,000 | User journey funnel analysis |

## Data Quality Rules

- **Referential integrity** — all FK values are validated against their PK sets before saving.
- **Temporal consistency** — `signup_date` < `transaction_date`; `event_timestamp` falls within its session window.
- **Business logic** — premium users have 3× transaction volume; enterprise users have 10% higher values; failed transactions have `$0` tax; mobile devices generate 60% of events.
- **Realistic distributions** — weekday transaction peaks, 40% weekend event drop, Q4 seasonal spike.

## Verify the Output

```python
import duckdb

con = duckdb.connect()

# Inspect a dimension table
con.execute("SELECT * FROM read_parquet('data/raw/dim_users.parquet') LIMIT 5").df()

# Check referential integrity
con.execute("""
    SELECT COUNT(*) AS orphan_transactions
    FROM read_parquet('data/raw/fact_transactions.parquet') t
    LEFT JOIN read_parquet('data/raw/dim_users.parquet') u USING (user_id)
    WHERE u.user_id IS NULL
""").fetchone()
```