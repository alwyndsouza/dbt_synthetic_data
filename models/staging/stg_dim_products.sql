-- Staging model for dim_products
-- Cleans and renames columns from the source product dimension table
{{ config(
    materialized='view',
    alias='stg_dim_products'
) }}

SELECT
    product_id,
    product_name,
    product_category,
    base_price,
    created_at
FROM {{ source('analytics_raw', 'dim_products') }}
