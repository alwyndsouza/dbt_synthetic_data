{{ config(materialized='view') }}

-- Staging model for fact_transactions: cleans and standardizes transaction data
SELECT
    transaction_id,
    user_id,
    product_id,
    location_id,
    transaction_date,
    transaction_timestamp,
    amount,
    currency,
    payment_status,
    discount_applied,
    tax_amount,
    -- Derived columns
    amount * discount_applied AS discount_amount,
    amount - (amount * discount_applied) AS net_amount,
    CASE
        WHEN payment_status = 'success' THEN amount
        ELSE 0
    END AS successful_amount,
    CASE
        WHEN payment_status = 'failed' THEN 1
        ELSE 0
    END AS is_failed,
    CASE
        WHEN payment_status = 'pending' THEN 1
        ELSE 0
    END AS is_pending
FROM {{ source('analytics_raw', 'fact_transactions') }}
