-- Geographic Performance Model - Semantic Layer
-- Grain: One row per location/country
-- Purpose: Regional revenue analytics and market performance
{{ config(
    materialized='table',
    alias='mart_geographic_performance'
) }}

WITH country_metrics AS (
    SELECT 
        l.location_id,
        l.country_code,
        l.country_name,
        l.region,
        l.timezone,
        l.latitude,
        l.longitude,
        
        -- Transaction metrics
        COUNT(DISTINCT t.transaction_id) AS transaction_count,
        SUM(t.amount) AS gross_revenue,
        SUM(t.discount_applied) AS total_discounts,
        SUM(t.tax_amount) AS total_taxes,
        SUM(t.amount - t.discount_applied - t.tax_amount) AS net_revenue,
        COUNT(DISTINCT t.user_id) AS unique_customers,
        
        -- Product diversity
        COUNT(DISTINCT t.product_id) AS unique_products_sold,
        
        -- Date range
        MIN(t.transaction_date) AS first_transaction_date,
        MAX(t.transaction_date) AS last_transaction_date
        
    FROM {{ ref('stg_dim_locations') }} l
    LEFT JOIN {{ ref('stg_fact_transactions') }} t 
        ON l.location_id = t.location_id AND t.payment_status = 'success'
    GROUP BY 
        l.location_id, l.country_code, l.country_name, l.region, l.timezone, l.latitude, l.longitude
),
region_aggregation AS (
    SELECT 
        region,
        SUM(transaction_count) AS region_transaction_count,
        SUM(gross_revenue) AS region_gross_revenue,
        SUM(net_revenue) AS region_net_revenue,
        SUM(unique_customers) AS region_unique_customers,
        COUNT(DISTINCT location_id) AS locations_in_region,
        COUNT(DISTINCT country_code) AS countries_in_region
    FROM country_metrics
    GROUP BY region
),
country_rankings AS (
    SELECT 
        country_code,
        country_name,
        region,
        net_revenue,
        transaction_count,
        unique_customers,
        ROW_NUMBER() OVER (ORDER BY net_revenue DESC) AS revenue_rank,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY net_revenue DESC) AS regional_rank
    FROM (
        SELECT 
            country_code,
            country_name,
            region,
            SUM(net_revenue) AS net_revenue,
            SUM(transaction_count) AS transaction_count,
            SUM(unique_customers) AS unique_customers
        FROM country_metrics
        GROUP BY country_code, country_name, region
    ) country_agg
)

SELECT
    cm.location_id,
    cm.country_code,
    cm.country_name,
    cm.region,
    cm.timezone,
    cm.latitude,
    cm.longitude,
    
    -- Transaction metrics
    COALESCE(cm.transaction_count, 0) AS transaction_count,
    COALESCE(cm.gross_revenue, 0) AS gross_revenue,
    COALESCE(cm.total_discounts, 0) AS total_discounts,
    COALESCE(cm.total_taxes, 0) AS total_taxes,
    COALESCE(cm.net_revenue, 0) AS net_revenue,
    COALESCE(cm.unique_customers, 0) AS unique_customers,
    COALESCE(cm.unique_products_sold, 0) AS unique_products_sold,
    
    -- Average metrics
    CASE 
        WHEN cm.transaction_count > 0 
        THEN cm.gross_revenue / cm.transaction_count 
        ELSE 0 
    END AS avg_order_value,
    
    CASE 
        WHEN cm.unique_customers > 0 
        THEN cm.net_revenue / cm.unique_customers 
        ELSE 0 
    END AS revenue_per_customer,
    
    -- Date context
    cm.first_transaction_date,
    cm.last_transaction_date,
    
    -- Region context
    ra.region_transaction_count,
    ra.region_gross_revenue,
    ra.region_net_revenue,
    ra.region_unique_customers,
    ra.locations_in_region,
    ra.countries_in_region,
    
    -- Share of region
    CASE 
        WHEN ra.region_net_revenue > 0 
        THEN cm.net_revenue / ra.region_net_revenue 
        ELSE 0 
    END AS share_of_region_revenue,
    
    -- Rankings
    cr.revenue_rank,
    cr.regional_rank,
    
    -- Market classification
    CASE 
        WHEN cr.revenue_rank <= 10 THEN 'top_market'
        WHEN cr.revenue_rank <= 50 THEN 'growth_market'
        WHEN cr.revenue_rank <= 100 THEN 'established_market'
        ELSE 'developing_market'
    END AS market_classification
        
FROM country_metrics cm
LEFT JOIN region_aggregation ra ON cm.region = ra.region
LEFT JOIN country_rankings cr ON cm.country_code = cr.country_code AND cm.region = cr.region
ORDER BY cm.net_revenue DESC NULLS LAST
