{{ config(materialized='table') }}

-- Transaction fact table with full dimension keys
SELECT
    t.transaction_id,
    t.user_id,
    t.product_id,
    t.location_id,
    t.transaction_date,
    t.transaction_timestamp,
    t.amount,
    t.currency,
    t.payment_status,
    t.discount_applied,
    t.tax_amount,
    t.discount_amount,
    t.net_amount,
    t.successful_amount,
    t.is_failed,
    t.is_pending,
    -- Enriched from dimensions
    u.user_tier,
    u.country AS user_country,
    p.product_name,
    p.product_category,
    p.base_price,
    l.country_code,
    l.region,
    l.timezone AS location_timezone
FROM {{ ref('stg_fact_transactions') }} t
LEFT JOIN {{ ref('stg_dim_users') }} u ON t.user_id = u.user_id
LEFT JOIN {{ ref('stg_dim_products') }} p ON t.product_id = p.product_id
LEFT JOIN {{ ref('stg_dim_locations') }} l ON t.location_id = l.location_id
