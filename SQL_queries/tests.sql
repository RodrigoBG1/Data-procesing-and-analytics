SELECT
    is_fraud,
    COUNT(*) as count
FROM fact_transactions
GROUP BY is_fraud;