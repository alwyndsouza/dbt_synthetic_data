-- Staging model for dim_locations
-- Cleans and renames columns from the source location dimension table
{{ config(
    materialized='view',
    alias='stg_dim_locations'
) }}

SELECT
    location_id,
    country_code,
    country_name,
    region,
    latitude,
    longitude,
    timezone
FROM {{ source('analytics_raw', 'dim_locations') }}
