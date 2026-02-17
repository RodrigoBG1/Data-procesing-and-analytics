WITH transaction_patterns AS (
    SELECT 
        f.transaction_id,
        d.full_date,
        d.day_name,
        EXTRACT(HOUR FROM d.full_date::timestamp) as hour_of_day,
        c.customer_id,
        c.credit_score_category,
        cd.card_brand,
        cd.card_tier,
        cd.card_on_dark_web,
        m.merchant_category_group,
        m.is_high_risk_mcc,
        f.amount,
        f.use_chip,
        f.is_fraud,
        
        -- Compare to customer's average
        AVG(f.amount) OVER (PARTITION BY f.customer_key) as customer_avg_amount,
        f.amount / NULLIF(AVG(f.amount) OVER (PARTITION BY f.customer_key), 0) as amount_vs_avg_ratio
        
    FROM fact_transactions f
    INNER JOIN dim_date d ON f.date_key = d.date_key
    INNER JOIN dim_customer c ON f.customer_key = c.customer_key
    INNER JOIN dim_card cd ON f.card_key = cd.card_key
    INNER JOIN dim_merchant m ON f.merchant_key = m.merchant_key
),
fraud_summary AS (
    -- Aggregate summary by fraud status
    SELECT
        is_fraud,
        COUNT(*) as transaction_count,
        ROUND(AVG(amount), 2) as avg_amount,
        ROUND(AVG(amount_vs_avg_ratio), 2) as avg_ratio_to_customer_avg,
        ROUND(100.0 * SUM(CASE WHEN card_on_dark_web THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_dark_web_cards,
        ROUND(100.0 * SUM(CASE WHEN is_high_risk_mcc THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_high_risk_mcc,
        ROUND(100.0 * SUM(CASE WHEN NOT use_chip THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_no_chip,
        ROUND(100.0 * SUM(CASE WHEN day_name IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_weekend,
        STRING_AGG(DISTINCT merchant_category_group, ', ') as common_categories
    FROM transaction_patterns
    GROUP BY is_fraud
)
-- First result set: Summary
SELECT * FROM fraud_summary
ORDER BY is_fraud DESC;

-- Second query: High-risk transactions detail
WITH transaction_patterns AS (
    SELECT
        f.transaction_id,
        d.full_date,
        d.day_name,
        c.customer_id,
        cd.card_brand,
        cd.card_on_dark_web,
        m.merchant_category_group,
        m.is_high_risk_mcc,
        f.amount,
        f.use_chip,
        f.is_fraud,
        f.amount / NULLIF(AVG(f.amount) OVER (PARTITION BY f.customer_key), 0) as amount_vs_avg_ratio

    FROM fact_transactions f
    INNER JOIN dim_date d ON f.date_key = d.date_key
    INNER JOIN dim_customer c ON f.customer_key = c.customer_key
    INNER JOIN dim_card cd ON f.card_key = cd.card_key
    INNER JOIN dim_merchant m ON f.merchant_key = m.merchant_key
)
SELECT
    transaction_id,
    full_date,
    customer_id,
    card_brand,
    merchant_category_group,
    amount,
    ROUND(amount_vs_avg_ratio, 2) as amount_ratio,
    card_on_dark_web,
    is_high_risk_mcc,
    use_chip,
    is_fraud
FROM transaction_patterns
WHERE
    amount_vs_avg_ratio > 3
    OR card_on_dark_web = TRUE
    OR (is_high_risk_mcc = TRUE AND amount > 500)
    OR (NOT use_chip AND amount > 200)
ORDER BY amount DESC
LIMIT 100;