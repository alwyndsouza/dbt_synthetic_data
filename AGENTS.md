# AGENTS.md — dbt Synthetic Data Project

## Overview

This project generates synthetic star-schema data for dbt + DuckDB. It creates 7 Parquet files (~500 MB) with 50K–5M rows each for analytics testing and development.

**Stack:** Python 3.12+, dbt-core, dbt-duckdb, DuckDB, pandas, pyarrow, Faker, numpy

---

## Build / Lint / Test Commands

### Setup (First Time)
```bash
# Full environment + packages + data generation
make setup

# Or step-by-step:
make install      # Create uv environment, install dependencies
make dbt-deps     # Install dbt packages (dbt_external_tables)
make data         # Generate synthetic Parquet files (~500 MB)
```

### Development Commands
```bash
# Regenerate data files
make data

# Install/refresh dependencies
make install
make dbt-deps

# dbt operations (run from project root with --profiles-dir .)
uv run dbt deps --profiles-dir .
uv run dbt build --profiles-dir .
uv run dbt run --profiles-dir .
uv run dbt test --profiles-dir .
uv run dbt compile --profiles-dir .  # Check SQL compilation

# Run a specific model
uv run dbt run --select stg_model_name --profiles-dir .

# Run tests for a specific model
uv run dbt test --select stg_model_name --profiles-dir .

# Source freshness check
uv run dbt source freshness --profiles-dir .
```

### Cleanup
```bash
make clean        # Remove data files and dbt artifacts
make clean-all    # Full cleanup
```

### Python Code Quality
```bash
# Format Python code (if ruff is installed)
uv run ruff format .

# Lint Python code
uv run ruff check .

# Run all checks (format + lint)
uv run ruff check . && uv run ruff format --check .
```

---

## Project Structure

```
dbt_synthetic_data/
├── models/              # dbt models (SQL)
│   ├── staging/         # Staging layer models
│   │   ├── stg_<source>.sql
│   │   ├── stg_<source>.yml   # Per-model tests and documentation
│   │   └── sources.yml         # Source definitions for Parquet files
│   ├── intermediate/   # Intermediate transformations
│   │   ├── int_<concept>.sql
│   │   └── int_<concept>.yml   # Per-model tests and documentation
│   └── marts/          # Final analytical models
│       ├── dim_<dimension>.sql
│       ├── dim_<dimension>.yml
│       ├── fct_<fact>.sql
│       └── fct_<fact>.yml
├── macros/              # dbt macros (Jinja SQL)
├── analyses/            # dbt analyses
├── tests/               # dbt schema/data tests
├── data/raw/            # Generated Parquet files (gitignored)
├── generate_data.py     # Data generation script
├── dbt_project.yml      # dbt project configuration
├── profiles.yml         # DuckDB connection settings
├── packages.yml         # dbt package dependencies
├── pyproject.toml       # Python dependencies (uv)
├── Makefile             # Common commands
└── target/              # dbt compiled SQL output (gitignored)
```

---

## Code Style Guidelines

### Python

#### Imports
```python
# Standard library first
import os
import sys
import uuid
from datetime import datetime, timedelta, date

# Third-party libraries
import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from faker import Faker

# No relative imports; use absolute module paths
```

#### Type Hints
```python
# Use type hints for function parameters and return types
def _uuids(n: int) -> np.ndarray:
    """Generate n UUID strings using numpy for performance."""
    return np.array([str(uuid.uuid4()) for _ in range(n)])

# Use specific types, avoid Any
def save_to_parquet(df: pd.DataFrame, filename: str, output_dir: str = OUTPUT_DIR) -> None:
    ...
```

#### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Modules | snake_case | `generate_data.py` |
| Functions | snake_case | `generate_dim_users()` |
| Classes | PascalCase | `DataGenerator` |
| Constants | UPPER_SNAKE_CASE | `RANDOM_SEED`, `N_USERS` |
| Private functions | _prefixed | `_uuids()`, `_check()` |
| Type variables | PascalCase | `T = TypeVar('T')` |
| SQL/dbt models | snake_case | `stg_users.sql`, `fact_transactions` |

#### Docstrings
```python
def generate_dim_users() -> pd.DataFrame:
    """Generate 50,000 user dimension rows."""
    ...

def generate_fact_transactions(
    users_df: pd.DataFrame,
    products_df: pd.DataFrame,
    locations_df: pd.DataFrame,
) -> pd.DataFrame:
    """
    Generate 1,000,000 transaction fact rows.

    Business rules applied:
    - Premium users have 3x higher transaction volume.
    - Enterprise users have 10% higher average transaction values.
    - Transaction volume peaks on weekdays; Q4 seasonal spike.
    """
    ...
```

#### Error Handling
```python
# Use sys.exit(1) for fatal validation errors
if errors:
    print("\nReferential integrity FAILED:")
    for e in errors:
        print(e)
    sys.exit(1)

# Collect all errors before failing
errors: list[str] = []
if bad.any():
    errors.append(f"  ✗ {label}: {bad.sum():,} orphan rows")

# Validate early, fail fast
if needs_fix.any():
    fix_count = int(needs_fix.sum())
    ...
```

#### Performance Considerations
```python
# Use numpy for bulk operations
rng = np.random.default_rng(RANDOM_SEED)
user_ids = rng.choice(len(users_df), size=n, p=tier_weights)

# Batch operations for large datasets
BATCH_SIZE = 100_000
while rows_generated < n:
    batch_n = min(BATCH_SIZE, n - rows_generated)
    ...
    print(f"  … {rows_generated:,} / {n:,} events generated", end="\r")

# Use numpy arrays over Python lists for numeric data
amounts = np.round(np.maximum(amounts, 0.01), 2)
```

---

## SQL / dbt Conventions

### Model Organization
```
models/
├── staging/          # Staging layer models
│   ├── stg_<source>.sql
│   ├── stg_<source>.yml   # Per-model tests and documentation
│   └── sources.yml        # Source definitions for Parquet files
├── intermediate/     # Intermediate transformations
│   ├── int_<concept>.sql
│   └── int_<concept>.yml  # Per-model tests and documentation
└── marts/            # Final analytical models
    ├── dim_<dimension>.sql
    ├── dim_<dimension>.yml
    ├── fct_<fact>.sql
    └── fct_<fact>.yml
```

### Model Naming
- **Staging models:** `stg_<source_table>_<source_name>.sql`
- **Intermediate models:** `int_<concept>_<verb>.sql`
- **Mart models:** `dim_<dimension>.sql` or `fct_<fact>.sql`

### SQL Style
```sql
-- Use CTEs for readability
WITH user_metrics AS (
    SELECT
        user_id,
        COUNT(*) AS transaction_count,
        SUM(amount) AS total_revenue
    FROM {{ ref('stg_transactions') }}
    GROUP BY 1
)

SELECT
    u.user_id,
    u.email,
    um.transaction_count,
    um.total_revenue
FROM {{ ref('dim_users') }} u
LEFT JOIN user_metrics um ON u.user_id = um.user_id
```

### dbt Jinja
```sql
-- Source references
{{ source('analytics_raw', 'dim_users') }}

-- Model references
{{ ref('stg_users') }}

-- Variables
{{ var('start_date', '2023-01-01') }}

-- Config at top of model
{{ config(
    materialized='incremental',
    unique_key='user_id'
) }}
```

### Source Definitions (sources.yml)
```yaml
version: 2

sources:
  - name: analytics_raw
    description: "Synthetic star-schema dataset for analytics"
    schema: main
    tables:
      - name: dim_users
        description: "User dimension — 50,000 synthetic users"
        meta:
          external_location: "read_parquet('data/raw/dim_users.parquet')"
```

---

## Data Quality Rules

When modifying `generate_data.py`, maintain these invariants:

1. **Referential integrity** — All FK values validated against PK sets before saving
2. **Temporal consistency** — `signup_date` < `transaction_date`; events within session windows
3. **Business logic** — Premium users 3× volume, enterprise users 10% higher values, failed txns $0 tax
4. **Realistic distributions** — Weekday peaks, 40% weekend drop, Q4 seasonal spike
5. **Fixed random seed** — `RANDOM_SEED = 42` for reproducible generation

---

## Common Tasks

### Adding a New Data Table
1. Add generator function to `generate_data.py` following existing patterns
2. Add to `main()` orchestrator
3. Add referential integrity validation
4. Add Parquet save call
5. Add source definition in `models/staging/sources.yml`
6. Regenerate: `make data`

### Adding a New dbt Model
1. Create SQL file in appropriate directory (staging/intermediate/marts)
2. Create a `<model_name>.yml` file in the same directory with tests and documentation
3. Run: `uv run dbt build --select model_name --profiles-dir .`

### Running dbt Commands
```bash
# Always include --profiles-dir . when running from project root
uv run dbt <command> --profiles-dir .

# Build specific model and its dependencies
uv run dbt build --select+ my_model --profiles-dir .

# Full project build
uv run dbt build --profiles-dir .
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| dbt-core | >=1.11.7 | dbt framework |
| dbt-duckdb | >=1.10.1 | DuckDB adapter |
| faker | >=40.13.0 | Synthetic data generation |
| numpy | >=2.4.4 | Numerical operations |
| pandas | >=3.0.2 | DataFrame operations |
| pyarrow | >=23.0.1 | Parquet file handling |

---

## Configuration Files

| File | Purpose |
|------|---------|
| `dbt_project.yml` | dbt project metadata, paths, target |
| `profiles.yml` | DuckDB connection (dev target) |
| `packages.yml` | External dbt packages |
| `pyproject.toml` | Python dependencies |
| `Makefile` | Build automation |
