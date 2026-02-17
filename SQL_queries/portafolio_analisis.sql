SELECT 
    cd.card_brand,
    cd.card_tier,
    
    -- Volume metrics
    COUNT(*) as transaction_count,
    COUNT(DISTINCT cd.card_key) as num_cards,
    ROUND(AVG(COUNT(*)) OVER (PARTITION BY cd.card_brand), 0) as avg_transactions_per_brand,
    
    -- Revenue metrics
    ROUND(SUM(f.amount), 2) as total_revenue,
    ROUND(AVG(f.amount), 2) as avg_transaction,
    ROUND(SUM(f.amount) / COUNT(DISTINCT cd.card_key), 2) as revenue_per_card,
    
    -- Risk metrics
    ROUND(100.0 * SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN cd.card_on_dark_web THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_dark_web,
    ROUND(100.0 * SUM(CASE WHEN f.use_chip THEN 1 ELSE 0 END) / COUNT(*), 2) as chip_usage_pct,
    
    -- Account age (maturity)
    ROUND(AVG(cd.account_age_years), 1) as avg_account_age_years,
    ROUND(AVG(cd.credit_limit), 2) as avg_credit_limit
    
FROM fact_transactions f
INNER JOIN dim_card cd ON f.card_key = cd.card_key
GROUP BY cd.card_brand, cd.card_tier
ORDER BY total_revenue DESC;

-- Cards with highest fraud risk
SELECT 
    cd.card_id,
    cd.card_brand,
    cd.card_tier,
    cd.card_on_dark_web,
    cd.account_age_years,
    cd.pin_age_years,
    COUNT(*) as transaction_count,
    SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) as fraud_count,
    ROUND(100.0 * SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct,
    ROUND(SUM(f.amount), 2) as total_spend
FROM fact_transactions f
INNER JOIN dim_card cd ON f.card_key = cd.card_key
GROUP BY cd.card_id, cd.card_brand, cd.card_tier, cd.card_on_dark_web, cd.account_age_years, cd.pin_age_years
HAVING COUNT(*) >= 10  -- At least 10 transactions
ORDER BY fraud_rate_pct DESC, total_spend DESC
LIMIT 50;