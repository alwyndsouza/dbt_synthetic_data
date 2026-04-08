-- Staging model for fact_sessions
-- Cleans and renames columns from the source session fact table
{{ config(
    materialized='view',
    alias='stg_fact_sessions'
) }}

SELECT
    session_id,
    user_id,
    device_id,
    start_time,
    end_time,
    session_duration_minutes,
    page_views,
    events_count
FROM {{ source('analytics_raw', 'fact_sessions') }}
