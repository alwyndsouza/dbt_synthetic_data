{{ config(materialized='view') }}

-- Staging model for dim_users: cleans and standardizes user data
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
    is_active,
    -- Derived columns
    CASE
        WHEN user_tier = 'enterprise' THEN TRUE
        ELSE FALSE
    END AS is_enterprise,
    CASE
        WHEN is_active = TRUE THEN 'active'
        ELSE 'inactive'
    END AS account_status
FROM {{ source('analytics_raw', 'dim_users') }}
