{{ config(materialized='view') }}

-- Intermediate model: daily aggregated metrics across all facts
WITH daily_transactions AS (
    SELECT
        DATE(transaction_timestamp) AS date,
        COUNT(*) AS transaction_count,
        SUM(amount) AS daily_revenue,
        SUM(successful_amount) AS daily_net_revenue,
        AVG(amount) AS avg_transaction_value,
        COUNT(DISTINCT user_id) AS unique_customers
    FROM {{ ref('stg_fact_transactions') }}
    GROUP BY DATE(transaction_timestamp)
),

daily_sessions AS (
    SELECT
        DATE(start_time) AS date,
        COUNT(*) AS session_count,
        AVG(session_duration_minutes) AS avg_session_duration,
        SUM(page_views) AS total_page_views,
        SUM(events_count) AS total_session_events,
        COUNT(DISTINCT user_id) AS unique_session_users
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY DATE(start_time)
),

daily_events AS (
    SELECT
        event_date AS date,
        COUNT(*) AS event_count,
        COUNT(CASE WHEN event_type = 'error' THEN 1 END) AS error_events,
        COUNT(CASE WHEN event_type = 'page_view' THEN 1 END) AS page_view_events,
        COUNT(DISTINCT user_id) AS unique_event_users
    FROM {{ ref('stg_fact_events') }}
    GROUP BY event_date
)

SELECT
    COALESCE(dt.date, ds.date, de.date) AS date,
    dt.transaction_count,
    dt.daily_revenue,
    dt.daily_net_revenue,
    dt.avg_transaction_value,
    dt.unique_customers AS transaction_users,
    ds.session_count,
    ds.avg_session_duration,
    ds.total_page_views,
    ds.total_session_events,
    ds.unique_session_users,
    de.event_count,
    de.error_events,
    de.page_view_events,
    de.unique_event_users
FROM daily_transactions dt
FULL OUTER JOIN daily_sessions ds ON dt.date = ds.date
FULL OUTER JOIN daily_events de ON COALESCE(dt.date, ds.date) = de.date
