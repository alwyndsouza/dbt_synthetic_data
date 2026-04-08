-- Enriched Session Model - Semantic Layer
-- Grain: One row per session
-- Purpose: Comprehensive session analysis with quality scoring and user context
{{ config(
    materialized='table',
    alias='mart_enriched_sessions'
) }}

WITH session_events AS (
    SELECT 
        session_id,
        COUNT(*) AS event_count,
        AVG(duration_seconds) AS avg_event_duration,
        COUNT(DISTINCT event_type) AS unique_event_types,
        COUNT(DISTINCT page_url) AS unique_pages
    FROM {{ ref('stg_fact_events') }}
    GROUP BY session_id
),
user_session_stats AS (
    SELECT 
        user_id,
        COUNT(*) AS total_user_sessions,
        AVG(session_duration_minutes) AS avg_session_duration,
        SUM(session_duration_minutes) AS total_session_time
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY user_id
)

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
    u.country AS user_country,
    u.signup_date,
    DATE_DIFF('day', u.signup_date, CAST(s.start_time AS DATE)) AS days_since_signup_at_session,
    
    -- Device attributes
    d.device_type,
    d.os,
    d.browser,
    CASE 
        WHEN d.device_type IN ('mobile', 'tablet') THEN 'mobile'
        ELSE 'desktop'
    END AS device_category,
    
    -- Event engagement
    COALESCE(se.event_count, 0) AS session_event_count,
    COALESCE(se.avg_event_duration, 0) AS avg_event_duration_seconds,
    COALESCE(se.unique_event_types, 0) AS unique_event_types,
    COALESCE(se.unique_pages, 0) AS unique_pages_visited,
    
    -- User session context
    uss.total_user_sessions,
    uss.avg_session_duration AS user_avg_session_duration,
    
    -- Session quality score (composite score 0-100)
    CASE 
        WHEN s.events_count >= 50 AND s.session_duration_minutes >= 20 THEN 100
        WHEN s.events_count >= 30 AND s.session_duration_minutes >= 15 THEN 80
        WHEN s.events_count >= 20 AND s.session_duration_minutes >= 10 THEN 60
        WHEN s.events_count >= 10 AND s.session_duration_minutes >= 5 THEN 40
        WHEN s.events_count >= 5 AND s.session_duration_minutes >= 2 THEN 20
        ELSE 10
    END AS session_quality_score,
    
    -- Session quality tier
    CASE 
        WHEN s.events_count >= 50 AND s.session_duration_minutes >= 20 THEN 'high_quality'
        WHEN s.events_count >= 20 AND s.session_duration_minutes >= 10 THEN 'medium_quality'
        WHEN s.events_count >= 5 AND s.session_duration_minutes >= 3 THEN 'low_quality'
        ELSE 'minimal'
    END AS session_quality_tier,
    
    -- Engagement depth
    CASE 
        WHEN s.page_views >= 20 THEN 'deep_engagement'
        WHEN s.page_views >= 10 THEN 'moderate_engagement'
        WHEN s.page_views >= 3 THEN 'light_engagement'
        ELSE 'minimal'
    END AS engagement_depth,
    
    -- Time-based metrics
    EXTRACT(HOUR FROM s.start_time) AS session_hour,
    CASE 
        WHEN EXTRACT(HOUR FROM s.start_time) BETWEEN 6 AND 11 THEN 'morning'
        WHEN EXTRACT(HOUR FROM s.start_time) BETWEEN 12 AND 17 THEN 'afternoon'
        WHEN EXTRACT(HOUR FROM s.start_time) BETWEEN 18 AND 21 THEN 'evening'
        ELSE 'night'
    END AS time_of_day
        
FROM {{ ref('stg_fact_sessions') }} s
LEFT JOIN {{ ref('stg_dim_users') }} u ON s.user_id = u.user_id
LEFT JOIN {{ ref('stg_dim_devices') }} d ON s.device_id = d.device_id
LEFT JOIN session_events se ON s.session_id = se.session_id
LEFT JOIN user_session_stats uss ON s.user_id = uss.user_id
