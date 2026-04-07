{{ config(materialized='view') }}

-- Staging model for dim_devices: cleans and standardizes device data
SELECT
    device_id,
    device_type,
    os,
    browser,
    -- Derived columns
    CASE
        WHEN device_type = 'mobile' THEN TRUE
        ELSE FALSE
    END AS is_mobile,
    CASE
        WHEN os IN ('iOS', 'Android') THEN 'mobile_os'
        WHEN os IN ('Windows', 'macOS', 'Linux') THEN 'desktop_os'
        ELSE 'other'
    END AS os_category
FROM {{ source('analytics_raw', 'dim_devices') }}
