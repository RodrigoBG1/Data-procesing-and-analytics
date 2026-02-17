SELECT 
    m.region,
    m.merchant_state,
    COUNT(*) as transaction_count,
    ROUND(SUM(f.amount), 2) as total_revenue,
    ROUND(AVG(f.amount), 2) as avg_transaction,
    COUNT(DISTINCT m.merchant_key) as num_merchants,
    COUNT(DISTINCT f.customer_key) as num_customers,
    ROUND(100.0 * SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct
FROM fact_transactions f
INNER JOIN dim_merchant m ON f.merchant_key = m.merchant_key
GROUP BY m.region, m.merchant_state
ORDER BY total_revenue DESC
LIMIT 20;

-- Transaction patterns by day and time
SELECT 
    d.day_name,
    d.is_weekend,
    d.quarter,
    COUNT(*) as transaction_count,
    ROUND(SUM(f.amount), 2) as total_revenue,
    ROUND(AVG(f.amount), 2) as avg_transaction,
    ROUND(100.0 * SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct_of_total_transactions
FROM fact_transactions f
INNER JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.day_name, d.is_weekend, d.quarter
ORDER BY 
    CASE d.day_name
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END;

-- Seasonal patterns (by quarter)
SELECT 
    d.year,
    d.quarter,
    COUNT(*) as transaction_count,
    ROUND(SUM(f.amount), 2) as total_revenue,
    ROUND(AVG(f.amount), 2) as avg_transaction,
    COUNT(DISTINCT f.customer_key) as unique_customers
FROM fact_transactions f
INNER JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;
