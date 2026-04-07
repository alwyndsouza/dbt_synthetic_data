{{ config(materialized='view') }}

-- Staging model for dim_products: cleans and standardizes product data
SELECT
    product_id,
    product_name,
    product_category,
    base_price,
    created_at,
    -- Derived columns
    CASE
        WHEN product_category = 'subscription' THEN 'recurring'
        ELSE 'one_time'
    END AS pricing_model,
    CASE
        WHEN base_price >= 100 THEN 'premium'
        WHEN base_price >= 50 THEN 'standard'
        ELSE 'basic'
    END AS price_tier
FROM {{ source('analytics_raw', 'dim_products') }}
