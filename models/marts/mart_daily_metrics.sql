-- Daily Metrics Mart
-- Grain: One row per day
-- Purpose: Daily KPIs - revenue, sessions, events, new users
{{ config(
    materialized='table',
    alias='mart_daily_metrics'
) }}

WITH daily_dates AS (
    -- Generate all dates in the range from transaction data
    SELECT DISTINCT transaction_date AS calendar_date
    FROM {{ ref('stg_fact_transactions') }}
    UNION
    SELECT DISTINCT CAST(start_time AS DATE) AS calendar_date
    FROM {{ ref('stg_fact_sessions') }}
    UNION
    SELECT DISTINCT CAST(event_timestamp AS DATE) AS calendar_date
    FROM {{ ref('stg_fact_events') }}
    UNION
    SELECT DISTINCT signup_date AS calendar_date
    FROM {{ ref('stg_dim_users') }}
),
daily_revenue AS (
    SELECT 
        transaction_date AS calendar_date,
        SUM(amount) AS total_revenue,
        SUM(amount - discount_applied) AS revenue_after_discount,
        SUM(tax_amount) AS tax_amount,
        SUM(amount - discount_applied - tax_amount) AS net_revenue,
        SUM(discount_applied) AS total_discount_given,
        COUNT(DISTINCT transaction_id) AS transaction_count,
        COUNT(DISTINCT user_id) AS unique_transacting_users,
        AVG(amount) AS avg_order_value
    FROM {{ ref('stg_fact_transactions') }}
    WHERE payment_status = 'success'
    GROUP BY transaction_date
),
daily_sessions AS (
    SELECT 
        CAST(start_time AS DATE) AS calendar_date,
        COUNT(DISTINCT session_id) AS total_sessions,
        SUM(session_duration_minutes) AS total_session_duration,
        AVG(session_duration_minutes) AS avg_session_duration,
        SUM(page_views) AS total_page_views,
        SUM(events_count) AS total_events,
        COUNT(DISTINCT user_id) AS unique_active_users
    FROM {{ ref('stg_fact_sessions') }}
    GROUP BY CAST(start_time AS DATE)
),
daily_events AS (
    SELECT 
        CAST(event_timestamp AS DATE) AS calendar_date,
        COUNT(*) AS event_count,
        COUNT(DISTINCT user_id) AS unique_event_users,
        AVG(duration_seconds) AS avg_time_on_page
    FROM {{ ref('stg_fact_events') }}
    GROUP BY CAST(event_timestamp AS DATE)
),
daily_new_users AS (
    SELECT 
        signup_date AS calendar_date,
        COUNT(*) AS new_users
    FROM {{ ref('stg_dim_users') }}
    GROUP BY signup_date
),
daily_moving_averages AS (
    SELECT 
        calendar_date,
        AVG(net_revenue) OVER (
            ORDER BY calendar_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS revenue_7day_moving_avg,
        AVG(net_revenue) OVER (
            ORDER BY calendar_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS revenue_30day_moving_avg
    FROM daily_revenue
),
yoy_comparison AS (
    SELECT 
        calendar_date,
        LAG(net_revenue, 365) OVER (ORDER BY calendar_date) AS prior_year_revenue
    FROM daily_revenue
)

SELECT
    d.calendar_date,
    
    -- Revenue metrics
    COALESCE(dr.total_revenue, 0) AS total_revenue,
    COALESCE(dr.revenue_after_discount, 0) AS revenue_after_discount,
    COALESCE(dr.tax_amount, 0) AS tax_amount,
    COALESCE(dr.net_revenue, 0) AS net_revenue,
    COALESCE(dr.total_discount_given, 0) AS total_discount_given,
    COALESCE(dr.transaction_count, 0) AS transaction_count,
    COALESCE(dr.unique_transacting_users, 0) AS unique_transacting_users,
    COALESCE(dr.avg_order_value, 0) AS avg_order_value,
    
    -- Session metrics
    COALESCE(ds.total_sessions, 0) AS total_sessions,
    COALESCE(ds.total_session_duration, 0) AS total_session_duration,
    COALESCE(ds.avg_session_duration, 0) AS avg_session_duration,
    COALESCE(ds.total_page_views, 0) AS total_page_views,
    COALESCE(ds.total_events, 0) AS session_events,
    COALESCE(ds.unique_active_users, 0) AS unique_active_users,
    
    -- Event metrics
    COALESCE(de.event_count, 0) AS total_events,
    COALESCE(de.unique_event_users, 0) AS unique_event_users,
    COALESCE(de.avg_time_on_page, 0) AS avg_time_on_page,
    
    -- User metrics
    COALESCE(dnu.new_users, 0) AS new_users,
    
    -- Moving averages
    dma.revenue_7day_moving_avg,
    dma.revenue_30day_moving_avg,
    
    -- Year-over-year
    yoy.prior_year_revenue,
    CASE 
        WHEN yoy.prior_year_revenue > 0 
        THEN (COALESCE(dr.net_revenue, 0) - yoy.prior_year_revenue) / yoy.prior_year_revenue * 100
        ELSE NULL 
    END AS yoy_growth_percentage
    
FROM daily_dates d
LEFT JOIN daily_revenue dr ON d.calendar_date = dr.calendar_date
LEFT JOIN daily_sessions ds ON d.calendar_date = ds.calendar_date
LEFT JOIN daily_events de ON d.calendar_date = de.calendar_date
LEFT JOIN daily_new_users dnu ON d.calendar_date = dnu.calendar_date
LEFT JOIN daily_moving_averages dma ON d.calendar_date = dma.calendar_date
LEFT JOIN yoy_comparison yoy ON d.calendar_date = yoy.calendar_date
ORDER BY d.calendar_date DESC
