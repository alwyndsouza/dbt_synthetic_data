-- Staging model for fact_transactions
-- Cleans and renames columns from the source transaction fact table
{{ config(
    materialized='view',
    alias='stg_fact_transactions'
) }}

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
    tax_amount
FROM {{ source('analytics_raw', 'fact_transactions') }}
