-- Intermediate model: Enriched transactions with user, product, and location details
-- Joins transaction facts with all dimension tables for complete transaction context
{{ config(
    materialized='view',
    alias='int_enriched_transactions'
) }}

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
    -- User dimensions
    u.email,
    u.first_name,
    u.last_name,
    u.country AS user_country,
    u.city AS user_city,
    u.user_tier,
    u.is_active AS user_is_active,
    u.signup_date,
    -- Product dimensions
    p.product_name,
    p.product_category,
    p.base_price,
    -- Location dimensions
    l.country_code,
    l.country_name,
    l.region,
    l.timezone AS location_timezone,
    -- Calculated fields
    t.amount - t.discount_applied AS revenue_after_discount,
    t.amount - t.discount_applied - t.tax_amount AS net_revenue
FROM {{ ref('stg_fact_transactions') }} t
LEFT JOIN {{ ref('stg_dim_users') }} u
    ON t.user_id = u.user_id
LEFT JOIN {{ ref('stg_dim_products') }} p
    ON t.product_id = p.product_id
LEFT JOIN {{ ref('stg_dim_locations') }} l
    ON t.location_id = l.location_id
