-- Staging model for fact_events
-- Cleans and renames columns from the source event fact table
{{ config(
    materialized='view',
    alias='stg_fact_events'
) }}

SELECT
    event_id,
    user_id,
    device_id,
    location_id,
    event_timestamp,
    event_type,
    page_url,
    session_id,
    duration_seconds
FROM {{ source('analytics_raw', 'fact_events') }}
