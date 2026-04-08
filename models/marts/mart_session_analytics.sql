-- Session Analytics Mart
-- Grain: One row per session
-- Purpose: Session-level metrics with device and user context
{{ config(
    materialized='table',
    alias='mart_session_analytics'
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
    
    -- User attributes
    u.email,
    u.first_name,
    u.last_name,
    u.user_tier,
    u.is_active AS user_is_active,
    u.signup_date,
    DATE_DIFF('day', u.signup_date, CAST(s.start_time AS DATE)) AS days_since_signup,
    
    -- Device attributes
    d.device_type,
    d.os,
    d.browser,
    
    -- Session quality score based on events and duration
    CASE 
        WHEN s.events_count > 50 AND s.session_duration_minutes > 20 THEN 'high_quality'
        WHEN s.events_count > 20 AND s.session_duration_minutes > 10 THEN 'medium_quality'
        WHEN s.events_count > 5 AND s.session_duration_minutes > 3 THEN 'low_quality'
        ELSE 'minimal'
    END AS session_quality_score,
    
    -- Engagement depth
    CASE 
        WHEN s.page_views > 20 THEN 'high_engagement'
        WHEN s.page_views > 10 THEN 'medium_engagement'
        WHEN s.page_views > 3 THEN 'low_engagement'
        ELSE 'minimal_engagement'
    END AS engagement_level,
    
    -- Calculated metrics
    CASE 
        WHEN s.session_duration_minutes > 0 
        THEN s.events_count / s.session_duration_minutes 
        ELSE 0 
    END AS events_per_minute,
    
    CASE 
        WHEN s.session_duration_minutes > 0 
        THEN s.page_views / s.session_duration_minutes 
        ELSE 0 
    END AS pages_per_minute
        
FROM {{ ref('stg_fact_sessions') }} s
LEFT JOIN {{ ref('stg_dim_users') }} u ON s.user_id = u.user_id
LEFT JOIN {{ ref('stg_dim_devices') }} d ON s.device_id = d.device_id
