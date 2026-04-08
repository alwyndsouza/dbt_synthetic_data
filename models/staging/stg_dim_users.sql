-- Staging model for dim_users
-- Cleans and renames columns from the source user dimension table
{{ config(
    materialized='view',
    alias='stg_dim_users'
) }}

SELECT
    user_id,
    email,
    first_name,
    last_name,
    country,
    city,
    timezone,
    signup_date,
    user_tier,
    is_active
FROM {{ source('analytics_raw', 'dim_users') }}
