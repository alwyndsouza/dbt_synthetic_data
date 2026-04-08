-- Transaction Summary Mart
-- Grain: One row per transaction
-- Purpose: Revenue analytics with geography and product context
{{ config(
    materialized='table',
    alias='mart_transaction_summary'
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
    
    -- User details
    u.email,
    u.first_name,
    u.last_name,
    u.user_tier,
    u.country AS user_country,
    u.city AS user_city,
    
    -- Product details
    p.product_name,
    p.product_category,
    p.base_price,
    
    -- Location details
    l.country_code,
    l.country_name,
    l.region,
    l.timezone AS location_timezone,
    
    -- Calculated revenue fields
    t.amount - t.discount_applied AS revenue_after_discount,
    t.amount - t.discount_applied - t.tax_amount AS net_revenue,
    
    -- Discount as percentage
    CASE 
        WHEN t.amount > 0 THEN t.discount_applied / t.amount 
        ELSE 0 
    END AS discount_percentage,
    
    -- Tax as percentage
    CASE 
        WHEN t.amount > 0 THEN t.tax_amount / t.amount 
        ELSE 0 
    END AS tax_percentage,
    
    -- Transaction status category
    CASE 
        WHEN t.payment_status = 'success' THEN 'completed'
        WHEN t.payment_status = 'pending' THEN 'pending'
        WHEN t.payment_status = 'failed' THEN 'failed'
        ELSE 'other'
    END AS transaction_category,
    
    -- Time-based fields
    EXTRACT(HOUR FROM t.transaction_timestamp) AS transaction_hour,
    EXTRACT(DAYOFWEEK FROM t.transaction_timestamp) AS day_of_week,
    EXTRACT(MONTH FROM t.transaction_timestamp) AS transaction_month,
    EXTRACT(YEAR FROM t.transaction_timestamp) AS transaction_year
        
FROM {{ ref('stg_fact_transactions') }} t
LEFT JOIN {{ ref('stg_dim_users') }} u ON t.user_id = u.user_id
LEFT JOIN {{ ref('stg_dim_products') }} p ON t.product_id = p.product_id
LEFT JOIN {{ ref('stg_dim_locations') }} l ON t.location_id = l.location_id
