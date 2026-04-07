# dbt Synthetic Data

Synthetic star-schema data generator for **dbt + DuckDB**. Generates 7 Parquet files (~500 MB) with 50K–5M rows each.

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
