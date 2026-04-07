{{ config(materialized='table') }}

-- Final product dimension with revenue analytics
WITH product_revenue AS (
    SELECT
        product_id,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN payment_status = 'success' THEN amount ELSE 0 END) AS total_revenue,
        AVG(CASE WHEN payment_status = 'success' THEN amount END) AS avg_order_value,
        COUNT(DISTINCT user_id) AS unique_buyers
    FROM {{ ref('stg_fact_transactions') }}
    GROUP BY product_id
)

SELECT
    p.product_id,
    p.product_name,
    p.product_category,
    p.base_price,
    p.pricing_model,
    p.price_tier,
    p.created_at,
    -- Revenue metrics
    COALESCE(pr.total_orders, 0) AS total_orders,
    COALESCE(pr.total_revenue, 0) AS total_revenue,
    COALESCE(pr.avg_order_value, 0) AS avg_order_value,
    COALESCE(pr.unique_buyers, 0) AS unique_buyers,
    -- Computed attributes
    CASE
        WHEN COALESCE(pr.total_revenue, 0) >= 100000 THEN 'top_performer'
        WHEN COALESCE(pr.total_revenue, 0) >= 10000 THEN 'growing'
        WHEN COALESCE(pr.total_revenue, 0) >= 1000 THEN 'established'
        ELSE 'new'
    END AS product_status
FROM {{ ref('stg_dim_products') }} p
LEFT JOIN product_revenue pr ON p.product_id = pr.product_id
