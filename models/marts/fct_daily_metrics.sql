{{ config(materialized='table') }}

-- Daily metrics fact table for time-series analysis
SELECT
    d.date,
    -- Transaction metrics
    COALESCE(d.transaction_count, 0) AS transaction_count,
    COALESCE(d.daily_revenue, 0) AS daily_revenue,
    COALESCE(d.daily_net_revenue, 0) AS daily_net_revenue,
    COALESCE(d.avg_transaction_value, 0) AS avg_transaction_value,
    COALESCE(d.transaction_users, 0) AS unique_transaction_users,
    -- Session metrics
    COALESCE(d.session_count, 0) AS session_count,
    COALESCE(d.avg_session_duration, 0) AS avg_session_duration,
    COALESCE(d.total_page_views, 0) AS total_page_views,
    COALESCE(d.total_session_events, 0) AS total_session_events,
    COALESCE(d.unique_session_users, 0) AS unique_session_users,
    -- Event metrics
    COALESCE(d.event_count, 0) AS event_count,
    COALESCE(d.error_events, 0) AS error_events,
    COALESCE(d.page_view_events, 0) AS page_view_events,
    COALESCE(d.unique_event_users, 0) AS unique_event_users,
    -- Derived metrics
    CASE
        WHEN COALESCE(d.event_count, 0) > 0 
        THEN ROUND(100.0 * COALESCE(d.error_events, 0) / d.event_count, 4)
        ELSE 0
    END AS error_rate,
    CASE
        WHEN COALESCE(d.transaction_users, 0) > 0
        THEN ROUND(d.daily_revenue / d.transaction_users, 2)
        ELSE 0
    END AS revenue_per_user
FROM {{ ref('int_daily_metrics') }} d
