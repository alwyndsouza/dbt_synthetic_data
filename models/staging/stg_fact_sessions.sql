{{ config(materialized='view') }}

-- Staging model for fact_sessions: cleans and standardizes session data
SELECT
    session_id,
    user_id,
    device_id,
    start_time,
    end_time,
    session_duration_minutes,
    page_views,
    events_count,
    -- Derived columns
    EXTRACT(HOUR FROM start_time) AS session_hour,
    EXTRACT(DAYOFWEEK FROM start_time) AS session_day_of_week,
    CASE
        WHEN session_duration_minutes < 5 THEN 'short'
        WHEN session_duration_minutes < 20 THEN 'medium'
        ELSE 'long'
    END AS session_length_category,
    events_count / NULLIF(page_views, 0) AS events_per_page
FROM {{ source('analytics_raw', 'fact_sessions') }}
