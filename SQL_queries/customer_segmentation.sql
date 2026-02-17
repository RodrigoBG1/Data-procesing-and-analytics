
WITH customer_metrics AS (
    SELECT 
        c.customer_key,
        c.customer_id,
        c.age_group,
        c.income_segment,
        c.credit_score_category,
        
        -- Recency
        CURRENT_DATE - MAX(d.full_date) as days_since_last_transaction,
        
        -- Frequency
        COUNT(*) as transaction_count,
        
        -- Monetary
        SUM(f.amount) as total_spend,
        AVG(f.amount) as avg_transaction,
        
        -- Fraud indicators
        SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) as fraud_count
        
    FROM fact_transactions f
    INNER JOIN dim_customer c ON f.customer_key = c.customer_key
    INNER JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY c.customer_key, c.customer_id, c.age_group, c.income_segment, c.credit_score_category
),
customer_segments AS (
    SELECT 
        *,
        -- RFM Score (1-5 scale)
        NTILE(5) OVER (ORDER BY days_since_last_transaction DESC) as recency_score,
        NTILE(5) OVER (ORDER BY transaction_count) as frequency_score,
        NTILE(5) OVER (ORDER BY total_spend) as monetary_score
    FROM customer_metrics
)
SELECT 
    customer_id,
    age_group,
    income_segment,
    credit_score_category,
    transaction_count,
    ROUND(total_spend, 2) as total_spend,
    ROUND(avg_transaction, 2) as avg_transaction,
    days_since_last_transaction,
    fraud_count,
    recency_score,
    frequency_score,
    monetary_score,
    -- Overall customer value
    CASE 
        WHEN monetary_score >= 4 AND frequency_score >= 4 THEN 'VIP'
        WHEN monetary_score >= 3 AND frequency_score >= 3 THEN 'High Value'
        WHEN recency_score <= 2 THEN 'At Risk'
        ELSE 'Regular'
    END as customer_segment
FROM customer_segments
ORDER BY total_spend DESC
LIMIT 100;