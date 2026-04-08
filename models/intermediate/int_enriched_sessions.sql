-- Intermediate model: Enriched sessions with user and device details
-- Joins session facts with user and device dimension tables
{{ config(
    materialized='view',
    alias='int_enriched_sessions'
) }}

SELECT
    s.session_id,
    s.user_id,
    s.device_id,
    s.start_time,
    s.end_time,
    s.session_duration_minutes,
    s.page_views,
    s.events_count,
    -- User dimensions
    u.email,
    u.first_name,
    u.last_name,
    u.country AS user_country,
    u.city AS user_city,
    u.user_tier,
    u.is_active AS user_is_active,
    u.signup_date,
    -- Device dimensions
    d.device_type,
    d.os,
    d.browser,
    -- Calculated fields
    CASE 
        WHEN s.events_count > 50 AND s.session_duration_minutes > 20 THEN 'high_quality'
        WHEN s.events_count > 20 AND s.session_duration_minutes > 10 THEN 'medium_quality'
        ELSE 'low_quality'
    END AS session_quality_score
FROM {{ ref('stg_fact_sessions') }} s
LEFT JOIN {{ ref('stg_dim_users') }} u
    ON s.user_id = u.user_id
LEFT JOIN {{ ref('stg_dim_devices') }} d
    ON s.device_id = d.device_id
