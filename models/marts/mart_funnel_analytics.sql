-- Funnel Analytics Model - Semantic Layer
-- Grain: One row per user
-- Purpose: User journey funnel - signup → first_session → first_transaction
{{ config(
    materialized='table',
    alias='mart_funnel_analytics'
) }}

WITH user_signup AS (
    SELECT 
        user_id,
        signup_date AS signup_date,
        user_tier,
        country,
        is_active
    FROM {{ ref('stg_dim_users') }}
),
user_first_session AS (
    SELECT 
        user_id,
        MIN(start_time) AS first_session_timestamp,
        MIN(CAST(start_time AS DATE)) AS first_session_date,
        MIN(device_id) AS first_session_device
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY user_id
),
user_first_transaction AS (
    SELECT 
        user_id,
        MIN(transaction_timestamp) AS first_transaction_timestamp,
        MIN(transaction_date) AS first_transaction_date,
        MIN(amount) AS first_transaction_amount,
        MIN(product_id) AS first_product_id
    FROM {{ ref('stg_fact_transactions') }}
    WHERE payment_status = 'success'
    GROUP BY user_id
),
user_engagement_summary AS (
    SELECT 
        s.user_id,
        COUNT(DISTINCT s.session_id) AS total_sessions,
        COUNT(DISTINCT t.transaction_id) AS total_transactions,
        SUM(s.session_duration_minutes) AS total_session_time,
        SUM(t.amount) AS lifetime_value
    FROM {{ ref('stg_fact_sessions') }} s
    LEFT JOIN {{ ref('stg_fact_transactions') }} t ON s.user_id = t.user_id AND t.payment_status = 'success'
    GROUP BY s.user_id
),
funnel_stages AS (
    SELECT 
        us.user_id,
        us.signup_date,
        us.user_tier,
        us.country,
        us.is_active,
        
        -- Stage 1: Signup (always exists)
        1 AS has_signed_up,
        
        -- Stage 2: First Session
        CASE WHEN ufs.first_session_timestamp IS NOT NULL THEN 1 ELSE 0 END AS has_started_session,
        ufs.first_session_timestamp,
        ufs.first_session_date,
        
        -- Stage 3: First Transaction
        CASE WHEN uft.first_transaction_timestamp IS NOT NULL THEN 1 ELSE 0 END AS has_converted,
        uft.first_transaction_timestamp,
        uft.first_transaction_date,
        uft.first_transaction_amount,
        
        -- Time to conversion
        CASE 
            WHEN uft.first_transaction_timestamp IS NOT NULL AND us.signup_date IS NOT NULL
            THEN DATE_DIFF('day', us.signup_date, uft.first_transaction_date)
            ELSE NULL 
        END AS days_to_conversion,
        
        CASE 
            WHEN uft.first_transaction_timestamp IS NOT NULL AND ufs.first_session_timestamp IS NOT NULL
            THEN (EXTRACT(EPOCH FROM uft.first_transaction_timestamp - ufs.first_session_timestamp) / 60)::INTEGER
            ELSE NULL 
        END AS minutes_session_to_purchase
        
    FROM user_signup us
    LEFT JOIN user_first_session ufs ON us.user_id = ufs.user_id
    LEFT JOIN user_first_transaction uft ON us.user_id = uft.user_id
)

SELECT
    fs.user_id,
    fs.signup_date,
    fs.user_tier,
    fs.country,
    fs.is_active,
    
    -- Funnel stages
    fs.has_signed_up,
    fs.has_started_session,
    fs.has_converted,
    
    -- Stage timestamps
    fs.first_session_timestamp,
    fs.first_session_date,
    fs.first_transaction_timestamp,
    fs.first_transaction_date,
    fs.first_transaction_amount,
    
    -- Conversion metrics
    fs.days_to_conversion,
    fs.minutes_session_to_purchase,
    
    -- Funnel conversion status
    CASE 
        WHEN fs.has_converted = 1 THEN 'converted'
        WHEN fs.has_started_session = 1 THEN 'session_started_not_converted'
        WHEN fs.has_signed_up = 1 THEN 'signed_up_not_engaged'
        ELSE 'inactive'
    END AS funnel_status,
    
    -- Conversion tier
    CASE 
        WHEN fs.days_to_conversion IS NOT NULL AND fs.days_to_conversion <= 7 THEN 'fast_converter'
        WHEN fs.days_to_conversion IS NOT NULL AND fs.days_to_conversion <= 30 THEN 'medium_converter'
        WHEN fs.days_to_conversion IS NOT NULL THEN 'slow_converter'
        WHEN fs.has_started_session = 1 THEN 'engaged_not_converted'
        ELSE 'not_engaged'
    END AS conversion_tier,
    
    -- Additional engagement
    ues.total_sessions,
    ues.total_transactions,
    ues.total_session_time,
    ues.lifetime_value
    
FROM funnel_stages fs
LEFT JOIN user_engagement_summary ues ON fs.user_id = ues.user_id
ORDER BY fs.signup_date DESC
