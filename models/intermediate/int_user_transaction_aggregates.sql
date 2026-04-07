{{ config(materialized='view') }}

-- Intermediate model: aggregates transaction metrics per user
WITH user_transactions AS (
    SELECT
        user_id,
        COUNT(*) AS total_transactions,
        COUNT(CASE WHEN payment_status = 'success' THEN 1 END) AS successful_transactions,
        COUNT(CASE WHEN payment_status = 'failed' THEN 1 END) AS failed_transactions,
        SUM(amount) AS total_revenue,
        SUM(successful_amount) AS net_revenue,
        AVG(amount) AS avg_transaction_value,
        MIN(transaction_date) AS first_transaction_date,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(DISTINCT DATE(transaction_date)) AS active_days
    FROM {{ ref('stg_fact_transactions') }}
    GROUP BY user_id
)

SELECT
    user_id,
    total_transactions,
    successful_transactions,
    failed_transactions,
    ROUND(100.0 * successful_transactions / NULLIF(total_transactions, 0), 2) AS success_rate,
    total_revenue,
    net_revenue,
    avg_transaction_value,
    first_transaction_date,
    last_transaction_date,
    active_days,
    DATE_DIFF('day', first_transaction_date, last_transaction_date) AS customer_lifetime_days
FROM user_transactions
