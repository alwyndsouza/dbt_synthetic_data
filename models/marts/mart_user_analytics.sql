-- User Analytics Mart
-- Grain: One row per user
-- Purpose: Consolidate user attributes with engagement and revenue metrics
{{ config(
    materialized='table',
    alias='mart_user_analytics'
) }}

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
    -- Calculate days since signup from the reference date
    DATE_DIFF('day', u.signup_date, DATE '2026-04-08') AS days_since_signup,
    
    -- Revenue metrics
    COALESCE(txn.total_revenue, 0) AS lifetime_value,
    COALESCE(txn.order_count, 0) AS order_count,
    CASE 
        WHEN COALESCE(txn.order_count, 0) > 0 
        THEN txn.total_revenue / txn.order_count 
        ELSE 0 
    END AS avg_order_value,
    COALESCE(txn.total_discount_given, 0) AS total_discount_given,
    COALESCE(txn.tax_paid, 0) AS tax_paid,
    COALESCE(txn.net_revenue, 0) AS net_revenue,
    
    -- Engagement metrics
    COALESCE(sess.total_sessions, 0) AS total_sessions,
    COALESCE(sess.total_session_duration, 0) AS total_session_duration_minutes,
    CASE 
        WHEN COALESCE(sess.total_sessions, 0) > 0 
        THEN sess.total_session_duration / sess.total_sessions 
        ELSE 0 
    END AS avg_session_duration,
    COALESCE(sess.total_page_views, 0) AS total_page_views,
    COALESCE(sess.total_events, 0) AS total_events,
    
    -- Calculated engagement scores
    CASE 
        WHEN COALESCE(sess.total_sessions, 0) >= 10 AND COALESCE(txn.order_count, 0) >= 3 THEN 'high_value'
        WHEN COALESCE(sess.total_sessions, 0) >= 5 AND COALESCE(txn.order_count, 0) >= 1 THEN 'medium_value'
        WHEN COALESCE(sess.total_sessions, 0) >= 1 THEN 'low_value'
        ELSE 'new'
    END AS user_segment
    
FROM {{ ref('stg_dim_users') }} u
LEFT JOIN (
    -- User-level transaction aggregations
    SELECT 
        user_id,
        SUM(amount) AS total_revenue,
        COUNT(DISTINCT transaction_id) AS order_count,
        SUM(discount_applied) AS total_discount_given,
        SUM(tax_amount) AS tax_paid,
        SUM(amount - discount_applied - tax_amount) AS net_revenue
    FROM {{ ref('stg_fact_transactions') }}
    WHERE payment_status = 'success'
    GROUP BY user_id
) txn ON u.user_id = txn.user_id
LEFT JOIN (
    -- User-level session aggregations
    SELECT 
        user_id,
        COUNT(DISTINCT session_id) AS total_sessions,
        SUM(session_duration_minutes) AS total_session_duration,
        SUM(page_views) AS total_page_views,
        SUM(events_count) AS total_events
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY user_id
) sess ON u.user_id = sess.user_id
