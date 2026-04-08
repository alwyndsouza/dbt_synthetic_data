-- Intermediate model: Enriched events with user, device, and location details
-- Joins event facts with all dimension tables
{{ config(
    materialized='view',
    alias='int_enriched_events'
) }}

SELECT
    e.event_id,
    e.user_id,
    e.device_id,
    e.location_id,
    e.event_timestamp,
    e.event_type,
    e.page_url,
    e.session_id,
    e.duration_seconds,
    -- User dimensions
    u.email,
    u.first_name,
    u.last_name,
    u.user_tier,
    u.is_active AS user_is_active,
    -- Device dimensions
    d.device_type,
    d.os,
    d.browser,
    -- Location dimensions
    l.country_code,
    l.country_name,
    l.region
FROM {{ ref('stg_fact_events') }} e
LEFT JOIN {{ ref('stg_dim_users') }} u
    ON e.user_id = u.user_id
LEFT JOIN {{ ref('stg_dim_devices') }} d
    ON e.device_id = d.device_id
LEFT JOIN {{ ref('stg_dim_locations') }} l
    ON e.location_id = l.location_id
