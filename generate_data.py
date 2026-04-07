"""
Synthetic Star-Schema Data Generator for dbt + DuckDB
======================================================
Generates a production-grade synthetic dataset simulating a digital product
analytics platform. Produces 7 Parquet files in a star-schema layout.

Usage:
    python generate_data.py

Output:
    data/raw/dim_users.parquet
    data/raw/dim_products.parquet
    data/raw/dim_locations.parquet
    data/raw/dim_devices.parquet
    data/raw/fact_transactions.parquet
    data/raw/fact_events.parquet
    data/raw/fact_sessions.parquet
"""

import os
import sys
import uuid
from datetime import datetime, timedelta, date

import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from faker import Faker

# ---------------------------------------------------------------------------
# Global settings
# ---------------------------------------------------------------------------
RANDOM_SEED = 42
np.random.seed(RANDOM_SEED)
fake = Faker()
Faker.seed(RANDOM_SEED)

OUTPUT_DIR = "data/raw"
BATCH_SIZE = 100_000

# Row counts
N_USERS = 50_000
N_PRODUCTS = 200
N_LOCATIONS = 500
N_DEVICES = 100
N_TRANSACTIONS = 1_000_000
N_EVENTS = 5_000_000
N_SESSIONS = 500_000

# Date boundaries
DATE_SIGNUP_START = date(2022, 1, 1)
DATE_SIGNUP_END = date(2024, 12, 31)
DATE_TXN_START = date(2023, 1, 1)
DATE_TXN_END = date(2026, 3, 31)
DATE_EVENT_START = datetime(2023, 1, 1)
DATE_EVENT_END = datetime(2026, 4, 7)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _uuids(n: int) -> np.ndarray:
    """Generate n UUID strings using numpy for performance."""
    return np.array([str(uuid.uuid4()) for _ in range(n)])


def _random_dates(start: date, end: date, n: int) -> np.ndarray:
    """Return n random date objects between start (inclusive) and end (inclusive)."""
    delta_days = (end - start).days
    offsets = np.random.randint(0, delta_days + 1, size=n)
    origin = pd.Timestamp(start)
    return pd.to_datetime(offsets, unit="D", origin=origin).date


def _random_timestamps(start: datetime, end: datetime, n: int) -> pd.DatetimeIndex:
    """Return n random UTC timestamps between start and end."""
    delta_seconds = int((end - start).total_seconds())
    offsets = np.random.randint(0, delta_seconds + 1, size=n)
    return pd.to_datetime(start) + pd.to_timedelta(offsets, unit="s")


def _weekday_weighted_dates(start: date, end: date, n: int) -> pd.DatetimeIndex:
    """
    Return n random dates between start and end, with weekdays (Mon-Fri)
    weighted 2x relative to weekends, plus a Q4 seasonal spike (+50%).
    """
    delta_days = (end - start).days
    days = np.arange(delta_days + 1)
    all_dates = [start + timedelta(days=int(d)) for d in days]

    weights = []
    for d in all_dates:
        w = 2.0 if d.weekday() < 5 else 1.0   # weekday boost
        if d.month in (11, 12):
            w *= 1.5                            # Q4 seasonal spike
        weights.append(w)

    weights = np.array(weights, dtype=np.float64)
    weights /= weights.sum()

    chosen_offsets = np.random.choice(delta_days + 1, size=n, p=weights)
    return pd.to_datetime([start + timedelta(days=int(o)) for o in chosen_offsets])


def _weekend_weighted_timestamps(start: datetime, end: datetime, n: int) -> pd.DatetimeIndex:
    """
    Return n random timestamps with events 40% lower on weekends.
    Uses day-level weighting then adds a random intra-day offset.
    """
    delta_days = (end - start).days
    days = np.arange(delta_days + 1)

    weights = np.where(
        np.array([(start + timedelta(days=int(d))).weekday() for d in days]) < 5,
        1.0,
        0.6,
    )
    # Q4 seasonal spike
    months = np.array([(start + timedelta(days=int(d))).month for d in days])
    weights = np.where(np.isin(months, [11, 12]), weights * 1.5, weights)
    weights /= weights.sum()

    chosen_day_offsets = np.random.choice(delta_days + 1, size=n, p=weights)
    intra_day_seconds = np.random.randint(0, 86400, size=n)
    ts = pd.to_datetime(start) + pd.to_timedelta(
        chosen_day_offsets * 86400 + intra_day_seconds, unit="s"
    )
    return ts


def _print_info(name: str, df: pd.DataFrame) -> None:
    """Print row count, memory, and first 5 rows for a DataFrame."""
    mem_mb = df.memory_usage(deep=True).sum() / 1024**2
    print(f"\n{'='*60}")
    print(f"  {name}")
    print(f"  rows={len(df):,}  memory={mem_mb:.1f} MB")
    print(f"{'='*60}")
    print(df.head(5).to_string(index=False))


# ---------------------------------------------------------------------------
# Dimension generators
# ---------------------------------------------------------------------------

def generate_dim_users() -> pd.DataFrame:
    """Generate 50,000 user dimension rows."""
    print("Generating dim_users …")

    n = N_USERS
    rng = np.random.default_rng(RANDOM_SEED)

    user_ids = _uuids(n)
    first_names = [fake.first_name() for _ in range(n)]
    last_names = [fake.last_name() for _ in range(n)]
    emails = [f"{fn.lower()}.{ln.lower()}{i}@{fake.free_email_domain()}"
              for i, (fn, ln) in enumerate(zip(first_names, last_names))]
    countries = [fake.country() for _ in range(n)]
    cities = [fake.city() for _ in range(n)]
    timezones = [fake.timezone() for _ in range(n)]
    signup_dates = _random_dates(DATE_SIGNUP_START, DATE_SIGNUP_END, n)
    user_tiers = rng.choice(
        ["free", "premium", "enterprise"],
        size=n,
        p=[0.70, 0.25, 0.05],
    )
    is_active = rng.random(n) < 0.80

    df = pd.DataFrame({
        "user_id": user_ids,
        "email": emails,
        "first_name": first_names,
        "last_name": last_names,
        "country": countries,
        "city": cities,
        "timezone": timezones,
        "signup_date": signup_dates,
        "user_tier": user_tiers,
        "is_active": is_active,
    })
    _print_info("dim_users", df)
    return df


def generate_dim_products() -> pd.DataFrame:
    """Generate 200 product dimension rows."""
    print("Generating dim_products …")

    n = N_PRODUCTS
    rng = np.random.default_rng(RANDOM_SEED + 1)

    product_names = (
        [f"Pro Plan {i}" for i in range(1, 51)]
        + [f"Analytics Module {i}" for i in range(1, 51)]
        + [f"Credit Pack {i}" for i in range(1, 51)]
        + [f"Enterprise Suite {i}" for i in range(1, 26)]
        + [f"Starter Add-on {i}" for i in range(1, 26)]
    )[:n]

    categories = rng.choice(
        ["subscription", "add-on", "credit_pack"],
        size=n,
        p=[0.50, 0.30, 0.20],
    )
    base_prices = np.round(rng.uniform(5.0, 500.0, size=n), 2)
    created_at = _random_timestamps(
        datetime(2020, 1, 1), datetime(2023, 12, 31), n
    )

    df = pd.DataFrame({
        "product_id": _uuids(n),
        "product_name": product_names,
        "product_category": categories,
        "base_price": base_prices,
        "created_at": created_at,
    })
    _print_info("dim_products", df)
    return df


def generate_dim_locations() -> pd.DataFrame:
    """Generate 500 location dimension rows."""
    print("Generating dim_locations …")

    n = N_LOCATIONS

    # ISO-3166-1 alpha-2 sample with regions and currency hints
    location_data = [
        ("US", "United States", "North America", "America/New_York"),
        ("GB", "United Kingdom", "Europe", "Europe/London"),
        ("DE", "Germany", "Europe", "Europe/Berlin"),
        ("FR", "France", "Europe", "Europe/Paris"),
        ("AU", "Australia", "Oceania", "Australia/Sydney"),
        ("CA", "Canada", "North America", "America/Toronto"),
        ("BR", "Brazil", "South America", "America/Sao_Paulo"),
        ("IN", "India", "Asia", "Asia/Kolkata"),
        ("JP", "Japan", "Asia", "Asia/Tokyo"),
        ("CN", "China", "Asia", "Asia/Shanghai"),
        ("ZA", "South Africa", "Africa", "Africa/Johannesburg"),
        ("NG", "Nigeria", "Africa", "Africa/Lagos"),
        ("MX", "Mexico", "North America", "America/Mexico_City"),
        ("AR", "Argentina", "South America", "America/Argentina/Buenos_Aires"),
        ("SG", "Singapore", "Asia", "Asia/Singapore"),
        ("NL", "Netherlands", "Europe", "Europe/Amsterdam"),
        ("ES", "Spain", "Europe", "Europe/Madrid"),
        ("IT", "Italy", "Europe", "Europe/Rome"),
        ("SE", "Sweden", "Europe", "Europe/Stockholm"),
        ("PL", "Poland", "Europe", "Europe/Warsaw"),
    ]

    rng = np.random.default_rng(RANDOM_SEED + 2)
    indices = rng.integers(0, len(location_data), size=n)
    rows = [location_data[i] for i in indices]

    country_codes = [r[0] for r in rows]
    country_names = [r[1] for r in rows]
    regions = [r[2] for r in rows]
    timezones = [r[3] for r in rows]
    latitudes = np.round(rng.uniform(-90, 90, size=n), 6)
    longitudes = np.round(rng.uniform(-180, 180, size=n), 6)

    df = pd.DataFrame({
        "location_id": _uuids(n),
        "country_code": country_codes,
        "country_name": country_names,
        "region": regions,
        "latitude": latitudes,
        "longitude": longitudes,
        "timezone": timezones,
    })
    _print_info("dim_locations", df)
    return df


def generate_dim_devices() -> pd.DataFrame:
    """Generate 100 device dimension rows."""
    print("Generating dim_devices …")

    n = N_DEVICES
    rng = np.random.default_rng(RANDOM_SEED + 3)

    device_types = rng.choice(
        ["mobile", "desktop", "tablet"],
        size=n,
        p=[0.60, 0.30, 0.10],
    )
    os_by_type = {
        "mobile":  ["iOS", "Android"],
        "desktop": ["Windows", "macOS", "Linux"],
        "tablet":  ["iOS", "Android"],
    }
    browser_by_os = {
        "iOS":     ["Safari", "Chrome"],
        "Android": ["Chrome", "Firefox"],
        "Windows": ["Chrome", "Edge", "Firefox"],
        "macOS":   ["Safari", "Chrome", "Firefox"],
        "Linux":   ["Chrome", "Firefox"],
    }

    oses = []
    browsers = []
    for dt in device_types:
        os = rng.choice(os_by_type[dt])
        oses.append(os)
        browsers.append(rng.choice(browser_by_os[os]))

    df = pd.DataFrame({
        "device_id": _uuids(n),
        "device_type": device_types,
        "os": oses,
        "browser": browsers,
    })
    _print_info("dim_devices", df)
    return df


# ---------------------------------------------------------------------------
# Fact generators
# ---------------------------------------------------------------------------

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
    - Failed transactions have $0 tax_amount.
    - User signup_date < transaction_date.
    """
    print("Generating fact_transactions (this may take a moment) …")

    n = N_TRANSACTIONS
    rng = np.random.default_rng(RANDOM_SEED + 4)

    # --- weighted user sampling (premium=3x, enterprise stays at base weight) ---
    tier_weights = users_df["user_tier"].map(
        {"free": 1.0, "premium": 3.0, "enterprise": 1.0}
    ).values.copy()
    tier_weights /= tier_weights.sum()
    user_indices = rng.choice(len(users_df), size=n, p=tier_weights)

    user_ids = users_df["user_id"].values[user_indices]
    user_signups = pd.to_datetime(users_df["signup_date"].values[user_indices])
    user_tiers_sel = users_df["user_tier"].values[user_indices]

    # --- transaction dates (weekday-weighted, Q4 spike) ---
    txn_dates = _weekday_weighted_dates(DATE_TXN_START, DATE_TXN_END, n)

    # Ensure transaction_date >= signup_date (shift if needed)
    signup_ts = pd.Series(user_signups)
    txn_ts = pd.Series(pd.to_datetime(txn_dates))
    needs_fix = txn_ts < signup_ts
    # For rows that need fixing, add 0-30 days to signup_date and clip to DATE_TXN_END
    if needs_fix.any():
        fix_count = int(needs_fix.sum())
        fix_offsets = rng.integers(0, 30, size=fix_count)
        fix_base = signup_ts[needs_fix.values].reset_index(drop=True)
        fixed_ts = fix_base + pd.to_timedelta(fix_offsets, unit="D")
        upper = pd.Timestamp(DATE_TXN_END)
        fixed_ts = fixed_ts.clip(upper=upper)
        txn_ts = txn_ts.copy()
        txn_ts.loc[needs_fix.values] = fixed_ts.values

    # Intra-day times
    intra_seconds = rng.integers(0, 86400, size=n)
    txn_timestamps = txn_ts + pd.to_timedelta(intra_seconds, unit="s")

    # --- product sampling ---
    product_indices = rng.integers(0, len(products_df), size=n)
    product_ids = products_df["product_id"].values[product_indices]
    base_prices = products_df["base_price"].values[product_indices].astype(float)

    # Enterprise users get 10% higher average transaction values
    enterprise_mask = user_tiers_sel == "enterprise"
    variance = rng.uniform(-0.20, 0.20, size=n)
    amounts = base_prices * (1 + variance)
    amounts[enterprise_mask] *= 1.10
    amounts = np.round(np.maximum(amounts, 0.01), 2)

    # --- location sampling ---
    location_indices = rng.integers(0, len(locations_df), size=n)
    location_ids = locations_df["location_id"].values[location_indices]
    country_codes = locations_df["country_code"].values[location_indices]

    currency_map = {
        "GB": "GBP", "AU": "AUD",
        "DE": "EUR", "FR": "EUR", "NL": "EUR",
        "ES": "EUR", "IT": "EUR", "SE": "EUR", "PL": "EUR",
    }
    currencies = np.array([currency_map.get(cc, "USD") for cc in country_codes])

    # --- payment_status ---
    payment_statuses = rng.choice(
        ["success", "failed", "pending"],
        size=n,
        p=[0.92, 0.05, 0.03],
    )

    # --- discount & tax ---
    discount_applied = np.round(rng.uniform(0.0, 0.50, size=n), 4)
    failed_mask = payment_statuses == "failed"
    tax_amount = np.round(amounts * 0.10, 2)
    tax_amount[failed_mask] = 0.00

    df = pd.DataFrame({
        "transaction_id": _uuids(n),
        "user_id": user_ids,
        "product_id": product_ids,
        "location_id": location_ids,
        "transaction_date": txn_ts.dt.date,
        "transaction_timestamp": txn_timestamps,
        "amount": amounts,
        "currency": currencies,
        "payment_status": payment_statuses,
        "discount_applied": discount_applied,
        "tax_amount": tax_amount,
    })
    _print_info("fact_transactions", df)
    return df


def generate_fact_sessions(
    users_df: pd.DataFrame,
    devices_df: pd.DataFrame,
) -> pd.DataFrame:
    """
    Generate 500,000 session fact rows.

    Business rules applied:
    - Mobile devices generate 60% of sessions (mirrors events distribution).
    - session start_time < end_time; duration calculated.
    """
    print("Generating fact_sessions …")

    n = N_SESSIONS
    rng = np.random.default_rng(RANDOM_SEED + 5)

    user_indices = rng.integers(0, len(users_df), size=n)
    user_ids = users_df["user_id"].values[user_indices]

    # Weight mobile devices 60%
    device_weights = devices_df["device_type"].map(
        {"mobile": 0.60, "desktop": 0.30, "tablet": 0.10}
    ).values.copy()
    device_weights /= device_weights.sum()
    device_indices = rng.choice(len(devices_df), size=n, p=device_weights)
    device_ids = devices_df["device_id"].values[device_indices]

    # Session start times
    start_times = _weekend_weighted_timestamps(DATE_EVENT_START, DATE_EVENT_END, n)

    # Session duration: 1-60 minutes
    duration_minutes = rng.integers(1, 61, size=n).astype(float)
    end_times = start_times + pd.to_timedelta(duration_minutes * 60, unit="s")

    page_views = rng.integers(1, 51, size=n)
    events_count = rng.integers(1, 101, size=n)

    session_ids = _uuids(n)

    df = pd.DataFrame({
        "session_id": session_ids,
        "user_id": user_ids,
        "device_id": device_ids,
        "start_time": start_times,
        "end_time": end_times,
        "session_duration_minutes": duration_minutes,
        "page_views": page_views,
        "events_count": events_count,
    })
    _print_info("fact_sessions", df)
    return df


def generate_fact_events(
    users_df: pd.DataFrame,
    devices_df: pd.DataFrame,
    locations_df: pd.DataFrame,
    sessions_df: pd.DataFrame,
) -> pd.DataFrame:
    """
    Generate 5,000,000 event fact rows in batches of BATCH_SIZE.

    Business rules applied:
    - Mobile devices generate 60% of events.
    - Event activity 40% lower on weekends; Q4 spike.
    - event_timestamp falls within [session.start_time, session.end_time].
    """
    print("Generating fact_events (batched, this takes the longest) …")

    n = N_EVENTS
    rng = np.random.default_rng(RANDOM_SEED + 6)

    page_urls = [
        "/dashboard", "/settings", "/reports", "/billing",
        "/profile", "/analytics", "/export", "/help",
        "/integrations", "/team", "/onboarding", "/upgrade",
    ]
    event_types = ["page_view", "button_click", "form_submit", "error", "logout"]

    # Weight mobile devices 60%
    device_weights = devices_df["device_type"].map(
        {"mobile": 0.60, "desktop": 0.30, "tablet": 0.10}
    ).values.copy()
    device_weights /= device_weights.sum()

    # Pre-compute session arrays for fast lookup
    session_ids_arr = sessions_df["session_id"].values
    session_starts = sessions_df["start_time"].values.astype("datetime64[s]")
    session_ends = sessions_df["end_time"].values.astype("datetime64[s]")
    session_user_ids = sessions_df["user_id"].values

    batches = []
    rows_generated = 0

    while rows_generated < n:
        batch_n = min(BATCH_SIZE, n - rows_generated)

        # Sample a session for each event (gives us user_id + time window)
        sess_indices = rng.integers(0, len(sessions_df), size=batch_n)
        s_ids = session_ids_arr[sess_indices]
        s_starts = pd.to_datetime(session_starts[sess_indices])
        s_ends = pd.to_datetime(session_ends[sess_indices])
        u_ids = session_user_ids[sess_indices]

        # Random timestamp within [start, end] for each event
        durations_s = ((s_ends - s_starts).total_seconds()).astype(int)
        durations_s = np.maximum(durations_s, 1)
        offsets = np.array([rng.integers(0, d) for d in durations_s])
        event_timestamps = s_starts + pd.to_timedelta(offsets, unit="s")

        # Device sampling
        dev_indices = rng.choice(len(devices_df), size=batch_n, p=device_weights)
        dev_ids = devices_df["device_id"].values[dev_indices]

        # Location sampling
        loc_indices = rng.integers(0, len(locations_df), size=batch_n)
        loc_ids = locations_df["location_id"].values[loc_indices]

        evt_types = rng.choice(event_types, size=batch_n)
        p_urls = rng.choice(page_urls, size=batch_n)
        durations_sec = rng.integers(1, 601, size=batch_n)

        batch_df = pd.DataFrame({
            "event_id": _uuids(batch_n),
            "user_id": u_ids,
            "device_id": dev_ids,
            "location_id": loc_ids,
            "event_timestamp": event_timestamps,
            "event_type": evt_types,
            "page_url": p_urls,
            "session_id": s_ids,
            "duration_seconds": durations_sec,
        })
        batches.append(batch_df)
        rows_generated += batch_n
        print(f"  … {rows_generated:,} / {n:,} events generated", end="\r")

    print()
    df = pd.concat(batches, ignore_index=True)
    _print_info("fact_events", df)
    return df


# ---------------------------------------------------------------------------
# Parquet writer
# ---------------------------------------------------------------------------

def save_to_parquet(
    df: pd.DataFrame,
    filename: str,
    output_dir: str = OUTPUT_DIR,
) -> None:
    """Write DataFrame to a Snappy-compressed Parquet file."""
    os.makedirs(output_dir, exist_ok=True)
    path = os.path.join(output_dir, filename)
    table = pa.Table.from_pandas(df, preserve_index=False)
    pq.write_table(table, path, compression="snappy")
    size_mb = os.path.getsize(path) / 1024**2
    print(f"  Saved {path}  ({size_mb:.1f} MB)")


# ---------------------------------------------------------------------------
# Referential integrity validator
# ---------------------------------------------------------------------------

def validate_referential_integrity(
    users_df: pd.DataFrame,
    products_df: pd.DataFrame,
    locations_df: pd.DataFrame,
    devices_df: pd.DataFrame,
    transactions_df: pd.DataFrame,
    events_df: pd.DataFrame,
    sessions_df: pd.DataFrame,
) -> None:
    """Assert all FK values exist in the corresponding PK sets."""
    print("\nValidating referential integrity …")
    errors: list[str] = []

    def _check(child_col: pd.Series, parent_col: pd.Series, label: str) -> None:
        bad = ~child_col.isin(parent_col)
        if bad.any():
            errors.append(f"  ✗ {label}: {bad.sum():,} orphan rows")
        else:
            print(f"  ✓ {label}")

    user_ids = users_df["user_id"]
    product_ids = products_df["product_id"]
    location_ids = locations_df["location_id"]
    device_ids = devices_df["device_id"]
    session_ids = sessions_df["session_id"]

    _check(transactions_df["user_id"], user_ids, "fact_transactions.user_id → dim_users")
    _check(transactions_df["product_id"], product_ids, "fact_transactions.product_id → dim_products")
    _check(transactions_df["location_id"], location_ids, "fact_transactions.location_id → dim_locations")

    _check(sessions_df["user_id"], user_ids, "fact_sessions.user_id → dim_users")
    _check(sessions_df["device_id"], device_ids, "fact_sessions.device_id → dim_devices")

    _check(events_df["user_id"], user_ids, "fact_events.user_id → dim_users")
    _check(events_df["device_id"], device_ids, "fact_events.device_id → dim_devices")
    _check(events_df["location_id"], location_ids, "fact_events.location_id → dim_locations")
    _check(events_df["session_id"], session_ids, "fact_events.session_id → fact_sessions")

    if errors:
        print("\nReferential integrity FAILED:")
        for e in errors:
            print(e)
        sys.exit(1)
    else:
        print("All referential integrity checks passed ✓")


# ---------------------------------------------------------------------------
# Main orchestrator
# ---------------------------------------------------------------------------

def main() -> None:
    start = datetime.now()
    print("=" * 60)
    print("  Synthetic Star-Schema Data Generator")
    print(f"  Started: {start.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    # --- dimension tables ---
    users_df = generate_dim_users()
    products_df = generate_dim_products()
    locations_df = generate_dim_locations()
    devices_df = generate_dim_devices()

    # --- fact tables ---
    transactions_df = generate_fact_transactions(users_df, products_df, locations_df)
    sessions_df = generate_fact_sessions(users_df, devices_df)
    events_df = generate_fact_events(users_df, devices_df, locations_df, sessions_df)

    # --- validate ---
    validate_referential_integrity(
        users_df, products_df, locations_df, devices_df,
        transactions_df, events_df, sessions_df,
    )

    # --- save ---
    print(f"\nSaving Parquet files to {OUTPUT_DIR}/ …")
    save_to_parquet(users_df, "dim_users.parquet")
    save_to_parquet(products_df, "dim_products.parquet")
    save_to_parquet(locations_df, "dim_locations.parquet")
    save_to_parquet(devices_df, "dim_devices.parquet")
    save_to_parquet(transactions_df, "fact_transactions.parquet")
    save_to_parquet(sessions_df, "fact_sessions.parquet")
    save_to_parquet(events_df, "fact_events.parquet")

    elapsed = (datetime.now() - start).total_seconds()
    print(f"\nDone in {elapsed:.1f}s ✓")


if __name__ == "__main__":
    main()
