{{ config(materialized='view') }}

-- Staging model for dim_locations: cleans and standardizes location data
SELECT
    location_id,
    country_code,
    country_name,
    region,
    latitude,
    longitude,
    timezone,
    -- Derived columns
    CASE
        WHEN region IN ('North America') THEN 'NA'
        WHEN region IN ('South America') THEN 'SA'
        WHEN region IN ('Europe') THEN 'EU'
        WHEN region IN ('Asia') THEN 'AS'
        WHEN region IN ('Africa') THEN 'AF'
        WHEN region IN ('Oceania') THEN 'OC'
        ELSE 'OTHER'
    END AS region_code
FROM {{ source('analytics_raw', 'dim_locations') }}
