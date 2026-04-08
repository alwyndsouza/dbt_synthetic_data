-- Enriched User Model - Semantic Layer
-- Grain: One row per user
-- Purpose: Comprehensive user profile with LTV, engagement, and segment classification
{{ config(
    materialized='table',
    alias='mart_enriched_users'
) }}

WITH user_transactions AS (
    SELECT 
        user_id,
        COUNT(DISTINCT transaction_id) AS transaction_count,
        SUM(amount) AS lifetime_value,
        SUM(discount_applied) AS total_discounts,
        SUM(tax_amount) AS total_taxes,
        SUM(amount - discount_applied - tax_amount) AS net_lifetime_value,
        MIN(transaction_date) AS first_purchase_date,
        MAX(transaction_date) AS last_purchase_date,
        COUNT(DISTINCT product_id) AS unique_products_purchased
    FROM {{ ref('stg_fact_transactions') }}
    WHERE payment_status = 'success'
    GROUP BY user_id
),
user_sessions AS (
    SELECT 
        user_id,
        COUNT(DISTINCT session_id) AS session_count,
        SUM(session_duration_minutes) AS total_session_time,
        AVG(session_duration_minutes) AS avg_session_time,
        SUM(page_views) AS total_page_views,
        SUM(events_count) AS total_events,
        MIN(start_time) AS first_session_date,
        MAX(start_time) AS last_session_date
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY user_id
),
ltv_percentiles AS (
    SELECT 
        PERCENTILE_CONT(0.80) WITHIN GROUP(ORDER BY net_lifetime_value) AS p80_ltv,
        PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY net_lifetime_value) AS p50_ltv,
        PERCENTILE_CONT(0.20) WITHIN GROUP(ORDER BY net_lifetime_value) AS p20_ltv
    FROM user_transactions
    WHERE net_lifetime_value > 0
),
engagement_percentiles AS (
    SELECT 
        PERCENTILE_CONT(0.80) WITHIN GROUP(ORDER BY session_count) AS p80_sessions,
        PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY session_count) AS p50_sessions
    FROM user_sessions
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
    DATE '2026-04-08' - u.signup_date AS days_since_signup,
    
    -- Transaction metrics
    COALESCE(ut.transaction_count, 0) AS order_count,
    COALESCE(ut.lifetime_value, 0) AS lifetime_value,
    COALESCE(ut.net_lifetime_value, 0) AS net_lifetime_value,
    COALESCE(ut.total_discounts, 0) AS total_discounts_received,
    COALESCE(ut.total_taxes, 0) AS total_taxes_paid,
    COALESCE(ut.unique_products_purchased, 0) AS unique_products_purchased,
    ut.first_purchase_date,
    ut.last_purchase_date,
    
    -- Session metrics
    COALESCE(us.session_count, 0) AS session_count,
    COALESCE(us.total_session_time, 0) AS total_session_minutes,
    COALESCE(us.avg_session_time, 0) AS avg_session_minutes,
    COALESCE(us.total_page_views, 0) AS total_page_views,
    COALESCE(us.total_events, 0) AS total_events,
    us.first_session_date,
    us.last_session_date,
    
    -- Average order value
    CASE 
        WHEN ut.transaction_count > 0 
        THEN ut.net_lifetime_value / ut.transaction_count 
        ELSE 0 
    END AS avg_order_value,
    
    -- User segment based on LTV and engagement
    CASE 
        WHEN ut.net_lifetime_value >= ltv_p.p80_ltv AND us.session_count >= eng_p.p80_sessions THEN 'champion'
        WHEN ut.net_lifetime_value >= ltv_p.p50_ltv AND us.session_count >= eng_p.p50_sessions THEN 'loyal_customer'
        WHEN ut.net_lifetime_value >= ltv_p.p50_ltv AND us.session_count < eng_p.p50_sessions THEN 'potential_loyalist'
        WHEN ut.net_lifetime_value < ltv_p.p20_ltv AND us.session_count >= eng_p.p50_sessions THEN 'at_risk'
        WHEN ut.net_lifetime_value < ltv_p.p20_ltv AND us.session_count < eng_p.p50_sessions THEN 'new_customer'
        WHEN ut.net_lifetime_value IS NULL AND us.session_count IS NULL THEN 'never_engaged'
        ELSE 'occasional'
    END AS user_segment,
    
    -- Activity status
    CASE 
        WHEN ut.last_purchase_date IS NOT NULL AND DATE '2026-04-08' - ut.last_purchase_date <= 30 THEN 'recent'
        WHEN ut.last_purchase_date IS NOT NULL AND DATE '2026-04-08' - ut.last_purchase_date <= 90 THEN 'active'
        WHEN ut.last_purchase_date IS NOT NULL AND DATE '2026-04-08' - ut.last_purchase_date <= 180 THEN 'lapsed'
        ELSE 'inactive'
    END AS activity_status
    
FROM {{ ref('stg_dim_users') }} u
LEFT JOIN user_transactions ut ON u.user_id = ut.user_id
LEFT JOIN user_sessions us ON u.user_id = us.user_id
CROSS JOIN ltv_percentiles ltv_p
CROSS JOIN engagement_percentiles eng_p
