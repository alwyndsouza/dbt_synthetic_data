-- Staging model for dim_devices
-- Cleans and renames columns from the source device dimension table
{{ config(
    materialized='view',
    alias='stg_dim_devices'
) }}

SELECT
    device_id,
    device_type,
    os,
    browser
FROM {{ source('analytics_raw', 'dim_devices') }}
