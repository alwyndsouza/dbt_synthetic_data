## My Data Schema
### Dimension Tables (from analytics_raw)
- dim_users: user_id, email, first_name, last_name, country, city, timezone, signup_date, user_tier, is_active (50K rows)
- dim_products: product_id, product_name, product_category, base_price, created_at (200 rows)
- dim_locations: location_id, country_code, country_name, region, latitude, longitude, timezone (500 rows)
- dim_devices: device_id, device_type, os, browser (100 rows)
### Fact Tables
- fact_transactions: transaction_id, user_id, product_id, location_id, transaction_date, transaction_timestamp, amount, currency, payment_status, discount_applied, tax_amount (1M rows)
- fact_sessions: session_id, user_id, device_id, start_time, end_time, session_duration_minutes, page_views, events_count (500K rows)
- fact_events: event_id, user_id, device_id, location_id, event_timestamp, event_type, page_url, session_id, duration_seconds (5M rows)
## Project Setup
- sources.yml already defined with source name `analytics_raw`
- Use DuckDB adapter for local parquet files
- Follow staging → intermediate → marts layer structure
- Use Incremental materialization for large fact-derived models
## Requested Models
### 1. User Analytics Mart
**Grain:** one row per user  
**Purpose:** Consolidate user attributes with engagement metrics
### 2. Product Performance Mart
**Grain:** one row per product  
**Purpose:** Product sales, revenue, and category performance
### 3. Session Analytics Mart
**Grain:** one row per session  
**Purpose:** Session-level metrics with device and user context
### 4. Transaction Summary Mart
**Grain:** one row per transaction (or daily grain)  
**Purpose:** Revenue analytics with geography and product context
### 5. Daily Metrics Mart
**Grain:** one row per day  
**Purpose:** Daily KPIs: revenue, sessions, events, new users
## Metrics to Create
Create these calculated metrics in appropriate marts:
### Revenue Metrics
- total_revenue: SUM(amount)
- revenue_after_discount: SUM(amount - discount_applied)
- tax_amount: SUM(tax_amount)
- net_revenue: SUM(amount - discount_applied - tax_amount)
- avg_order_value: total_revenue / COUNT(DISTINCT transaction_id)
- total_discount_given: SUM(discount_applied)
### Engagement Metrics
- total_sessions: COUNT(DISTINCT session_id)
- total_events: COUNT(event_id)
- avg_session_duration: AVG(session_duration_minutes)
- total_page_views: SUM(page_views)
- events_per_session: SUM(events_count) / COUNT(DISTINCT session_id)
- avg_time_on_page: AVG(duration_seconds)
### User Metrics
- total_users: COUNT(DISTINCT user_id)
- active_users: COUNT(DISTINCT user_id WHERE is_active = true)
- new_users: COUNT(DISTINCT user_id) WHERE signup_date = current_date
- user_tier_distribution: COUNT by user_tier
- conversion_rate: total_transactions / total_users
### Product Metrics
- products_sold: COUNT(DISTINCT product_id)
- top_products: RANK by total revenue
- category_performance: Aggregations by product_category
### Time-Based Metrics
- daily_revenue: Daily aggregation
- weekly_revenue: Weekly aggregation
- month_to_date_revenue: MTD aggregation
- year_over_year: YoY comparison
- moving_averages: 7-day, 30-day rolling averages
## Semantic Models (Enhanced Business Logic)
Create semantic/enriched models that:
### 1. Enriched User Model
- Join dim_users with fact_transactions, fact_sessions
- Add: lifetime_value, order_count, avg_order_value, days_since_signup
- Add: user segment (based on tier, LTV, engagement)
### 2. Enriched Product Model
- Join dim_products with fact_transactions
- Add: total_units_sold, total_revenue, avg_price_sold
- Add: product performance tier (bestseller, regular, slow_mover)
### 3. Enriched Session Model
- Join fact_sessions with dim_devices, dim_users
- Add: session_quality score based on events_count and duration
- Add: device category, user segment
### 4. Geographic Performance Model
- Join dim_locations with fact_transactions
- Add: country-level aggregations
- Add: regional revenue, top markets
### 5. Funnel Analytics Model
- Create user journey funnel: signup → first_session → first_transaction
- Calculate conversion at each step
- Add: time_to_conversion
## Requirements
- Follow existing naming conventions (prefix models with dim_, fct_, or core_)
- Add model.yml for every model with descriptions and tests (unique, not_null on primary keys)
- Use config block to set materialization (table for marts, view for intermediate)
- Match existing model patterns in the project
- Create all metrics as calculated fields within the models (not separate metric objects)
- Use CASE statements for conditional logic (e.g., payment_status filters)
- After building, verify row counts and sample values match expectations
- Include column descriptions explaining each metric calculation