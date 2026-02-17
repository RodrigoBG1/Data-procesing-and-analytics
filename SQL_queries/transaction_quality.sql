WITH quality_metrics AS (
    SELECT
        COUNT(*) as total_transactions,
        SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) as error_transactions,
        SUM(CASE WHEN f.use_chip THEN 1 ELSE 0 END) as chip_transactions,
        ROUND(100.0 * SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) / COUNT(*), 2) as error_rate_pct,
        ROUND(100.0 * SUM(CASE WHEN f.use_chip THEN 1 ELSE 0 END) / COUNT(*), 2) as chip_usage_pct,

        -- Error impact
        SUM(CASE WHEN f.has_errors THEN f.amount ELSE 0 END) as error_transaction_value,
        ROUND(100.0 * SUM(CASE WHEN f.has_errors THEN f.amount ELSE 0 END) / SUM(f.amount), 2) as error_value_pct
    FROM fact_transactions f
)
SELECT * FROM quality_metrics;

-- Error Analysis by Merchant Category
SELECT
    m.merchant_category_group,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) as error_count,
    ROUND(100.0 * SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) / COUNT(*), 2) as error_rate_pct,
    ROUND(AVG(f.amount), 2) as avg_transaction,
    ROUND(SUM(f.amount), 2) as total_value
FROM fact_transactions f
INNER JOIN dim_merchant m ON f.merchant_key = m.merchant_key
GROUP BY m.merchant_category_group
ORDER BY error_rate_pct DESC;

-- Chip Usage vs Non-Chip (Security Analysis)
SELECT
    f.use_chip,
    COUNT(*) as transaction_count,
    ROUND(AVG(f.amount), 2) as avg_amount,
    ROUND(SUM(f.amount), 2) as total_amount,
    ROUND(100.0 * SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) / COUNT(*), 2) as error_rate_pct,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct_of_total
FROM fact_transactions f
GROUP BY f.use_chip;

-- Error Trends Over Time
SELECT
    d.year,
    d.quarter,
    COUNT(*) as transactions,
    SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) as errors,
    ROUND(100.0 * SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) / COUNT(*), 3) as error_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN f.use_chip THEN 1 ELSE 0 END) / COUNT(*), 2) as chip_usage_pct
FROM fact_transactions f
INNER JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

-- High-Risk Merchants (by error rate)
SELECT
    m.merchant_id,
    m.merchant_category_group,
    m.merchant_city,
    m.merchant_state,
    COUNT(*) as transaction_count,
    SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) as error_count,
    ROUND(100.0 * SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) / COUNT(*), 2) as error_rate_pct,
    ROUND(SUM(f.amount), 2) as total_value
FROM fact_transactions f
INNER JOIN dim_merchant m ON f.merchant_key = m.merchant_key
GROUP BY m.merchant_id, m.merchant_category_group, m.merchant_city, m.merchant_state
HAVING COUNT(*) >= 1000  -- Minimum transaction threshold
ORDER BY error_rate_pct DESC
LIMIT 20;