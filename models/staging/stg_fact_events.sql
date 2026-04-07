{{ config(materialized='view') }}

-- Staging model for fact_events: cleans and standardizes event data
SELECT
    event_id,
    user_id,
    device_id,
    location_id,
    event_timestamp,
    event_type,
    page_url,
    session_id,
    duration_seconds,
    -- Derived columns
    CAST(event_timestamp AS DATE) AS event_date,
    EXTRACT(HOUR FROM event_timestamp) AS event_hour,
    EXTRACT(DAYOFWEEK FROM event_timestamp) AS event_day_of_week,
    CASE
        WHEN event_type = 'error' THEN TRUE
        ELSE FALSE
    END AS is_error_event
FROM {{ source('analytics_raw', 'fact_events') }}
