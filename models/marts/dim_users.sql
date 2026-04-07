{{ config(materialized='table') }}

-- Final user dimension with enriched attributes from transactions and sessions
WITH user_metrics AS (
    SELECT
        user_id,
        COUNT(*) AS total_transactions,
        SUM(CASE WHEN payment_status = 'success' THEN amount ELSE 0 END) AS lifetime_value,
        MAX(transaction_timestamp) AS last_purchase_date
    FROM {{ ref('stg_fact_transactions') }}
    GROUP BY user_id
),

session_metrics AS (
    SELECT
        user_id,
        COUNT(*) AS total_sessions,
        AVG(session_duration_minutes) AS avg_session_duration,
        SUM(page_views) AS total_page_views,
        MAX(start_time) AS last_session_date
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY user_id
)

SELECT
    u.user_id,
    u.email,
    u.first_name,
    u.last_name,
    u.country,
    u.city,
    u.timezone,
    u.signup_date,
    u.user_tier,
    u.is_active,
    u.account_status,
    u.is_enterprise,
    -- Transaction metrics
    COALESCE(um.total_transactions, 0) AS total_transactions,
    COALESCE(um.lifetime_value, 0) AS lifetime_value,
    um.last_purchase_date,
    -- Session metrics
    COALESCE(sm.total_sessions, 0) AS total_sessions,
    sm.avg_session_duration,
    sm.total_page_views,
    sm.last_session_date,
    -- Computed attributes
    CASE
        WHEN um.lifetime_value >= 1000 THEN 'high_value'
        WHEN um.lifetime_value >= 100 THEN 'medium_value'
        ELSE 'low_value'
    END AS customer_value_segment,
    CASE
        WHEN sm.last_session_date IS NULL THEN 'churned'
        WHEN sm.last_session_date >= CURRENT_DATE - INTERVAL '7 days' THEN 'active'
        WHEN sm.last_session_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'at_risk'
        ELSE 'inactive'
    END AS engagement_status
FROM {{ ref('stg_dim_users') }} u
LEFT JOIN user_metrics um ON u.user_id = um.user_id
LEFT JOIN session_metrics sm ON u.user_id = sm.user_id
