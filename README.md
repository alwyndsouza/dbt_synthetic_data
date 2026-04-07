# dbt Synthetic Data

Synthetic star-schema data generator for a **dbt + DuckDB** analytics project.
Generates 7 Parquet files (~500 MB compressed) simulating a digital product
analytics platform with users, products, locations, devices, transactions,
sessions, and events.

## Prerequisites

- Python 3.12+
- [uv](https://docs.astral.sh/uv/) — fast Python package and project manager

### Install uv

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Or via pip
pip install uv
```

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/alwyndsouza/dbt_synthetic_data.git
cd dbt_synthetic_data

# 2. Create the virtual environment and install all dependencies
uv sync

# 3. Generate the synthetic dataset
uv run generate_data.py
```

This will create the following files under `data/raw/`:

```
data/
└── raw/
    ├── dim_users.parquet          (~50,000 rows)
    ├── dim_products.parquet       (~200 rows)
    ├── dim_locations.parquet      (~500 rows)
    ├── dim_devices.parquet        (~100 rows)
    ├── fact_transactions.parquet  (~1,000,000 rows)
    ├── fact_sessions.parquet      (~500,000 rows)
    └── fact_events.parquet        (~5,000,000 rows)
```

Generation takes **under 2 minutes** on a standard laptop.

## Project Structure

```
dbt_synthetic_data/
├── generate_data.py          # Data generation script
├── pyproject.toml            # Project metadata and dependencies (uv)
├── uv.lock                   # Locked dependency versions
├── .python-version           # Pinned Python version for uv
├── data/
│   └── raw/                  # Generated Parquet files (git-ignored)
└── models/
    └── staging/
        └── sources.yml       # dbt source definitions
```

## Dependencies

All dependencies are managed by **uv** and declared in `pyproject.toml`:

| Package    | Purpose                               |
|------------|---------------------------------------|
| `pandas`   | DataFrame construction and I/O        |
| `numpy`    | Vectorised random data generation     |
| `faker`    | Realistic names, emails, timezones    |
| `pyarrow`  | Snappy-compressed Parquet writing     |

### Managing dependencies

```bash
# Add a new dependency
uv add <package>

# Remove a dependency
uv remove <package>

# Upgrade all dependencies to latest compatible versions
uv lock --upgrade
uv sync
```

## dbt Configuration

The `models/staging/sources.yml` file is ready to use with **dbt-duckdb**.
It declares all 7 tables as external sources that read directly from the
Parquet files via DuckDB's `read_parquet` function.

### dbt setup

```bash
# Install dbt-duckdb alongside project dependencies
uv add dbt-core dbt-duckdb

# Verify dbt can read all sources
uv run dbt source freshness
```

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
