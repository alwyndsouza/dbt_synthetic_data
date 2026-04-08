-- Enriched Product Model - Semantic Layer
-- Grain: One row per product
-- Purpose: Comprehensive product performance with sales, revenue, and tier classification
{{ config(
    materialized='table',
    alias='mart_enriched_products'
) }}

WITH product_stats AS (
    SELECT 
        product_id,
        COUNT(*) AS total_transactions,
        COUNT(DISTINCT transaction_id) AS unique_transactions,
        SUM(amount) AS gross_revenue,
        SUM(discount_applied) AS total_discounts,
        SUM(tax_amount) AS total_taxes,
        SUM(amount - discount_applied - tax_amount) AS net_revenue,
        COUNT(DISTINCT user_id) AS unique_buyers,
        MIN(transaction_date) AS first_sale_date,
        MAX(transaction_date) AS last_sale_date
    FROM {{ ref('stg_fact_transactions') }}
    WHERE payment_status = 'success'
    GROUP BY product_id
),
revenue_thresholds AS (
    SELECT 
        PERCENTILE_CONT(0.90) WITHIN GROUP(ORDER BY net_revenue) AS p90_revenue,
        PERCENTILE_CONT(0.70) WITHIN GROUP(ORDER BY net_revenue) AS p70_revenue,
        PERCENTILE_CONT(0.30) WITHIN GROUP(ORDER BY net_revenue) AS p30_revenue
    FROM product_stats
    WHERE net_revenue > 0
),
units_thresholds AS (
    SELECT 
        PERCENTILE_CONT(0.90) WITHIN GROUP(ORDER BY total_transactions) AS p90_units,
        PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY total_transactions) AS p50_units
    FROM product_stats
    WHERE total_transactions > 0
)

SELECT
    p.product_id,
    p.product_name,
    p.product_category,
    p.base_price,
    p.created_at,
    
    -- Sales volume
    COALESCE(ps.total_transactions, 0) AS units_sold,
    COALESCE(ps.unique_transactions, 0) AS unique_transactions,
    COALESCE(ps.unique_buyers, 0) AS unique_buyers,
    
    -- Revenue metrics
    COALESCE(ps.gross_revenue, 0) AS gross_revenue,
    COALESCE(ps.net_revenue, 0) AS net_revenue,
    COALESCE(ps.total_discounts, 0) AS total_discounts_given,
    COALESCE(ps.total_taxes, 0) AS total_taxes_collected,
    
    -- Average metrics
    CASE 
        WHEN ps.total_transactions > 0 
        THEN ps.gross_revenue / ps.total_transactions 
        ELSE 0 
    END AS avg_transaction_value,
    
    CASE 
        WHEN ps.total_transactions > 0 
        THEN ps.net_revenue / ps.total_transactions 
        ELSE 0 
    END AS avg_net_transaction_value,
    
    CASE 
        WHEN ps.gross_revenue > 0 
        THEN ps.total_discounts / ps.gross_revenue 
        ELSE 0 
    END AS discount_rate,
    
    CASE 
        WHEN ps.unique_buyers > 0 
        THEN ps.total_transactions / ps.unique_buyers 
        ELSE 0 
    END AS repeat_purchase_rate,
    
    -- Date range
    ps.first_sale_date,
    ps.last_sale_date,
    CASE 
        WHEN ps.first_sale_date IS NOT NULL 
        THEN DATE '2026-04-08' - ps.first_sale_date 
        ELSE NULL 
    END AS product_age_days,
    
    -- Performance tier
    CASE 
        WHEN ps.net_revenue IS NULL OR ps.net_revenue = 0 THEN 'no_sales'
        WHEN ps.net_revenue >= rt.p90_revenue AND ps.total_transactions >= ut.p90_units THEN 'bestseller'
        WHEN ps.net_revenue >= rt.p70_revenue AND ps.total_transactions >= ut.p50_units THEN 'strong_performer'
        WHEN ps.net_revenue >= rt.p30_revenue THEN 'regular'
        ELSE 'slow_mover'
    END AS product_performance_tier,
    
    -- Category ranking within product category
    ROW_NUMBER() OVER (
        PARTITION BY p.product_category 
        ORDER BY ps.net_revenue DESC
    ) AS category_rank
        
FROM {{ ref('stg_dim_products') }} p
LEFT JOIN product_stats ps ON p.product_id = ps.product_id
CROSS JOIN revenue_thresholds rt
CROSS JOIN units_thresholds ut
ORDER BY ps.net_revenue DESC NULLS LAST
