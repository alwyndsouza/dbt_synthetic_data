{{ config(materialized='view') }}

-- Intermediate model: summarizes events per session
WITH session_events AS (
    SELECT
        session_id,
        COUNT(*) AS total_events,
        COUNT(DISTINCT event_type) AS unique_event_types,
        COUNT(DISTINCT page_url) AS unique_pages,
        SUM(duration_seconds) AS total_duration,
        AVG(duration_seconds) AS avg_event_duration,
        COUNT(CASE WHEN event_type = 'error' THEN 1 END) AS error_count,
        COUNT(CASE WHEN event_type = 'page_view' THEN 1 END) AS page_view_count,
        COUNT(CASE WHEN event_type = 'button_click' THEN 1 END) AS button_click_count,
        COUNT(CASE WHEN event_type = 'form_submit' THEN 1 END) AS form_submit_count
    FROM {{ ref('stg_fact_events') }}
    GROUP BY session_id
)

SELECT
    se.session_id,
    se.total_events,
    se.unique_event_types,
    se.unique_pages,
    se.total_duration,
    se.avg_event_duration,
    se.error_count,
    se.page_view_count,
    se.button_click_count,
    se.form_submit_count,
    s.session_duration_minutes,
    s.page_views,
    CASE
        WHEN s.session_duration_minutes > 0 THEN se.total_events / s.session_duration_minutes
        ELSE 0
    END AS events_per_minute
FROM session_events se
LEFT JOIN {{ ref('stg_fact_sessions') }} s ON se.session_id = s.session_id
