WITH monthly_revenue AS (
    SELECT 
        d.year,
        d.month,
        d.month_name,
        COUNT(*) as transaction_count,
        SUM(f.amount) as total_revenue,
        AVG(f.amount) as avg_transaction,
        COUNT(DISTINCT f.customer_key) as unique_customers,
        SUM(CASE WHEN f.is_fraud THEN f.amount ELSE 0 END) as fraud_revenue
    FROM fact_transactions f
    INNER JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month, d.month_name
    ORDER BY d.year, d.month
)
SELECT 
    year,
    month,
    month_name,
    transaction_count,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(avg_transaction, 2) as avg_transaction,
    unique_customers,
    ROUND(fraud_revenue, 2) as fraud_revenue,
    ROUND(100.0 * fraud_revenue / NULLIF(total_revenue, 0), 2) as fraud_rate_pct,
    
    -- Month-over-Month growth
    ROUND(100.0 * (total_revenue - LAG(total_revenue) OVER (ORDER BY year, month)) 
          / NULLIF(LAG(total_revenue) OVER (ORDER BY year, month), 0), 2) as mom_growth_pct
FROM monthly_revenue;

-- Revenue by merchant category
SELECT 
    m.merchant_category_group,
    COUNT(*) as transaction_count,
    ROUND(SUM(f.amount), 2) as total_revenue,
    ROUND(AVG(f.amount), 2) as avg_transaction,
    ROUND(100.0 * SUM(f.amount) / SUM(SUM(f.amount)) OVER (), 2) as pct_of_total_revenue,
    COUNT(DISTINCT f.customer_key) as unique_customers
FROM fact_transactions f
INNER JOIN dim_merchant m ON f.merchant_key = m.merchant_key
GROUP BY m.merchant_category_group
ORDER BY total_revenue DESC;

-- Revenue by customer segment
SELECT 
    c.age_group,
    c.income_segment,
    c.credit_score_category,
    COUNT(*) as transaction_count,
    ROUND(SUM(f.amount), 2) as total_revenue,
    ROUND(AVG(f.amount), 2) as avg_transaction,
    COUNT(DISTINCT c.customer_key) as unique_customers
FROM fact_transactions f
INNER JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.age_group, c.income_segment, c.credit_score_category
ORDER BY total_revenue DESC
LIMIT 20;
