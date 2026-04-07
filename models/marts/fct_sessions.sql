{{ config(materialized='table') }}

-- Session fact with device enrichment for analytics
SELECT
    s.session_id,
    s.user_id,
    s.device_id,
    s.start_time,
    s.end_time,
    s.session_duration_minutes,
    s.page_views,
    s.events_count,
    -- Device information
    d.device_type,
    d.os,
    d.browser,
    -- Derived device flags
    CASE
        WHEN d.device_type = 'mobile' THEN TRUE
        ELSE FALSE
    END AS is_mobile,
    CASE
        WHEN d.os IN ('iOS', 'Android') THEN TRUE
        ELSE FALSE
    END AS is_mobile_os,
    -- Session time features
    EXTRACT(HOUR FROM s.start_time) AS session_hour,
    EXTRACT(DAYOFWEEK FROM s.start_time) AS session_day_of_week,
    CASE
        WHEN s.session_duration_minutes < 5 THEN 'short'
        WHEN s.session_duration_minutes < 20 THEN 'medium'
        ELSE 'long'
    END AS session_length_category
FROM {{ ref('stg_fact_sessions') }} s
LEFT JOIN {{ ref('stg_dim_devices') }} d ON s.device_id = d.device_id
