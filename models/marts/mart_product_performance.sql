-- Product Performance Mart
-- Grain: One row per product
-- Purpose: Product sales, revenue, and category performance
{{ config(
    materialized='table',
    alias='mart_product_performance'
) }}

WITH product_sales AS (
    SELECT 
        product_id,
        COUNT(*) AS units_sold,
        SUM(amount) AS total_revenue,
        SUM(discount_applied) AS total_discount,
        SUM(tax_amount) AS tax_collected,
        SUM(amount - discount_applied - tax_amount) AS net_revenue,
        COUNT(DISTINCT transaction_id) AS transaction_count,
        COUNT(DISTINCT user_id) AS unique_customers
    FROM {{ ref('stg_fact_transactions') }}
    WHERE payment_status = 'success'
    GROUP BY product_id
),
sales_thresholds AS (
    SELECT 
        PERCENTILE_CONT(0.90) WITHIN GROUP(ORDER BY units_sold) as p90_threshold,
        PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY units_sold) as p50_threshold
    FROM product_sales
    WHERE units_sold > 0
)

SELECT
    p.product_id,
    p.product_name,
    p.product_category,
    p.base_price,
    p.created_at,
    
    -- Sales metrics
    COALESCE(ps.units_sold, 0) AS total_units_sold,
    COALESCE(ps.total_revenue, 0) AS total_revenue,
    COALESCE(ps.total_discount, 0) AS total_discount_given,
    COALESCE(ps.tax_collected, 0) AS tax_collected,
    COALESCE(ps.net_revenue, 0) AS net_revenue,
    
    -- Average metrics
    CASE 
        WHEN COALESCE(ps.units_sold, 0) > 0 
        THEN ps.total_revenue / ps.units_sold 
        ELSE 0 
    END AS avg_price_sold,
    
    CASE 
        WHEN COALESCE(ps.total_revenue, 0) > 0 
        THEN ps.total_discount / ps.total_revenue 
        ELSE 0 
    END AS discount_rate,
    
    -- Transaction counts
    COALESCE(ps.transaction_count, 0) AS transaction_count,
    COALESCE(ps.unique_customers, 0) AS unique_customers,
    
    -- Performance tier
    CASE 
        WHEN COALESCE(ps.units_sold, 0) = 0 THEN 'no_sales'
        WHEN ps.units_sold >= st.p90_threshold THEN 'bestseller'
        WHEN ps.units_sold >= st.p50_threshold THEN 'regular'
        ELSE 'slow_mover'
    END AS product_performance_tier
    
FROM {{ ref('stg_dim_products') }} p
LEFT JOIN product_sales ps ON p.product_id = ps.product_id
CROSS JOIN sales_thresholds st
