{{ config(materialized='table') }}

-- User activity fact table for user-level analytics
WITH user_transactions AS (
    SELECT
        user_id,
        COUNT(*) AS transaction_count,
        SUM(CASE WHEN payment_status = 'success' THEN amount ELSE 0 END) AS total_revenue,
        COUNT(DISTINCT DATE(transaction_timestamp)) AS active_days
    FROM {{ ref('stg_fact_transactions') }}
    GROUP BY user_id
),

user_sessions AS (
    SELECT
        user_id,
        COUNT(*) AS session_count,
        AVG(session_duration_minutes) AS avg_session_duration,
        SUM(page_views) AS total_page_views,
        SUM(events_count) AS total_events,
        MIN(start_time) AS first_session,
        MAX(start_time) AS last_session
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY user_id
),

user_events AS (
    SELECT
        user_id,
        COUNT(*) AS event_count,
        COUNT(DISTINCT event_type) AS unique_event_types,
        COUNT(DISTINCT page_url) AS unique_pages_visited,
        COUNT(CASE WHEN event_type = 'error' THEN 1 END) AS error_count
    FROM {{ ref('stg_fact_events') }}
    GROUP BY user_id
)

SELECT
    u.user_id,
    u.signup_date,
    u.user_tier,
    u.is_active,
    u.country,
    u.timezone,
    -- Transaction activity
    COALESCE(ut.transaction_count, 0) AS transaction_count,
    COALESCE(ut.total_revenue, 0) AS lifetime_revenue,
    COALESCE(ut.active_days, 0) AS active_days,
    -- Session activity
    COALESCE(us.session_count, 0) AS session_count,
    COALESCE(us.avg_session_duration, 0) AS avg_session_duration,
    COALESCE(us.total_page_views, 0) AS total_page_views,
    COALESCE(us.total_events, 0) AS total_events,
    us.first_session,
    us.last_session,
    -- Event activity
    COALESCE(ue.event_count, 0) AS event_count,
    COALESCE(ue.unique_event_types, 0) AS unique_event_types,
    COALESCE(ue.unique_pages_visited, 0) AS unique_pages_visited,
    COALESCE(ue.error_count, 0) AS error_count,
    -- Engagement score (composite metric)
    ROUND(
        COALESCE(us.session_count, 0) * 0.3 +
        COALESCE(ue.event_count, 0) / 1000.0 * 0.3 +
        COALESCE(ut.transaction_count, 0) * 0.2 +
        CASE WHEN ue.error_count = 0 THEN 0.2 ELSE 0 END,
        2
    ) AS engagement_score
FROM {{ ref('stg_dim_users') }} u
LEFT JOIN user_transactions ut ON u.user_id = ut.user_id
LEFT JOIN user_sessions us ON u.user_id = us.user_id
LEFT JOIN user_events ue ON u.user_id = ue.user_id
