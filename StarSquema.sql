-- ========================================
-- TRANSACTION DATA WAREHOUSE - STAR SCHEMA
-- PostgreSQL DDL
-- ========================================
-- SECURITY NOTE: This schema uses card tokenization instead of
-- storing sensitive PAN (Primary Account Number) data to comply
-- with PCI-DSS requirements.
-- ========================================

DROP TABLE IF EXISTS fact_transactions CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_card CASCADE;
DROP TABLE IF EXISTS dim_merchant CASCADE;

DROP SEQUENCE IF EXISTS seq_customer_key CASCADE;
DROP SEQUENCE IF EXISTS seq_card_key CASCADE;
DROP SEQUENCE IF EXISTS seq_merchant_key CASCADE;

-- ========================================
-- SEQUENCES
-- ========================================

CREATE SEQUENCE seq_customer_key START 1 INCREMENT 1;
CREATE SEQUENCE seq_card_key START 1 INCREMENT 1;
CREATE SEQUENCE seq_merchant_key START 1 INCREMENT 1;

-- ========================================
-- DIMENSION: dim_date
-- ========================================

CREATE TABLE dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day INTEGER NOT NULL,
    day_name VARCHAR(10) NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_of_year INTEGER NOT NULL,
    week_of_year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    quarter INTEGER NOT NULL,
    year INTEGER NOT NULL,
    is_weekend BOOLEAN NOT NULL DEFAULT FALSE,
    is_holiday BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_date_full_date ON dim_date(full_date);
CREATE INDEX idx_date_year_month ON dim_date(year, month);
CREATE INDEX idx_date_year ON dim_date(year);
CREATE INDEX idx_date_quarter ON dim_date(year, quarter);

-- ========================================
-- DIMENSION: dim_customer
-- ========================================

CREATE TABLE dim_customer (
    customer_key INTEGER PRIMARY KEY DEFAULT nextval('seq_customer_key'),
    customer_id VARCHAR(100) NOT NULL UNIQUE,  -- Expanded from 50
    current_age INTEGER,
    retirement_age INTEGER,
    birth_year INTEGER,
    birth_month INTEGER,
    gender VARCHAR(10),
    address VARCHAR(500),  -- Expanded from 255
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    per_capita_income DECIMAL(10, 2),
    yearly_income DECIMAL(12, 2),
    total_debt DECIMAL(12, 2),
    credit_score INTEGER,
    num_credit_cards INTEGER,
    age_group VARCHAR(20),
    income_segment VARCHAR(20),
    credit_score_category VARCHAR(20),
    debt_to_income_ratio DECIMAL(5, 2)
);

CREATE INDEX idx_customer_id ON dim_customer(customer_id);
CREATE INDEX idx_customer_age_group ON dim_customer(age_group);
CREATE INDEX idx_customer_income_segment ON dim_customer(income_segment);
CREATE INDEX idx_customer_credit_score ON dim_customer(credit_score);
CREATE INDEX idx_customer_credit_category ON dim_customer(credit_score_category);

-- ========================================
-- DIMENSION: dim_card (PCI-DSS Compliant)
-- ========================================
-- SECURITY NOTES:
-- - card_token: SHA-256 hash of card number (irreversible, for tracking)
-- - last_4_digits: Only last 4 digits for customer service
-- - card_number: NOT STORED (PCI-DSS compliance)
-- - cvv: NOT STORED (PCI-DSS requirement - never store CVV)
-- ========================================

CREATE TABLE dim_card (
    card_key INTEGER PRIMARY KEY DEFAULT nextval('seq_card_key'),
    card_id VARCHAR(100) NOT NULL UNIQUE,  -- Expanded from 50
    customer_id VARCHAR(100),  -- Expanded from 50
    card_brand VARCHAR(50),
    card_type VARCHAR(50),
    card_token VARCHAR(64) NOT NULL,  -- SHA-256 hash for tracking same card
    last_4_digits VARCHAR(4),         -- For display/customer service only
    has_chip BOOLEAN NOT NULL DEFAULT TRUE,
    expires DATE,
    num_cards_issued INTEGER,
    credit_limit DECIMAL(10, 2),
    acct_open_date DATE,
    year_pin_last_changed INTEGER,
    card_on_dark_web BOOLEAN NOT NULL DEFAULT FALSE,
    account_age_days INTEGER,
    account_age_years DECIMAL(5, 2),
    pin_age_years INTEGER,
    card_tier VARCHAR(20)
);

CREATE INDEX idx_card_id ON dim_card(card_id);
CREATE INDEX idx_card_customer_id ON dim_card(customer_id);
CREATE INDEX idx_card_brand ON dim_card(card_brand);
CREATE INDEX idx_card_type ON dim_card(card_type);
CREATE INDEX idx_card_tier ON dim_card(card_tier);
CREATE INDEX idx_card_dark_web ON dim_card(card_on_dark_web);
CREATE INDEX idx_card_expires ON dim_card(expires);
CREATE INDEX idx_card_token ON dim_card(card_token);  -- For fraud detection queries

-- ========================================
-- DIMENSION: dim_merchant
-- ========================================

CREATE TABLE dim_merchant (
    merchant_key INTEGER PRIMARY KEY DEFAULT nextval('seq_merchant_key'),
    merchant_id VARCHAR(100) NOT NULL UNIQUE,  -- Expanded from 50
    merchant_city VARCHAR(200),  -- Expanded from 100
    merchant_state VARCHAR(2),
    zip VARCHAR(10),
    mcc INTEGER,
    mcc_description VARCHAR(200),  -- Expanded from 100
    merchant_category_group VARCHAR(50),
    region VARCHAR(20),
    is_high_risk_mcc BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_merchant_id ON dim_merchant(merchant_id);
CREATE INDEX idx_merchant_state ON dim_merchant(merchant_state);
CREATE INDEX idx_merchant_mcc ON dim_merchant(mcc);
CREATE INDEX idx_merchant_category ON dim_merchant(merchant_category_group);
CREATE INDEX idx_merchant_region ON dim_merchant(region);
CREATE INDEX idx_merchant_high_risk ON dim_merchant(is_high_risk_mcc);

-- ========================================
-- FACT: fact_transactions
-- ========================================

CREATE TABLE fact_transactions (
    transaction_id BIGSERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL,
    customer_key INTEGER NOT NULL,
    card_key INTEGER NOT NULL,
    merchant_key INTEGER NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,  
    use_chip BOOLEAN NOT NULL DEFAULT FALSE,
    has_errors BOOLEAN NOT NULL DEFAULT FALSE,
    error_code TEXT, 
    is_fraud BOOLEAN NOT NULL DEFAULT FALSE,
    
    CONSTRAINT fk_fact_date 
        FOREIGN KEY (date_key) 
        REFERENCES dim_date(date_key),
    
    CONSTRAINT fk_fact_customer 
        FOREIGN KEY (customer_key) 
        REFERENCES dim_customer(customer_key),
    
    CONSTRAINT fk_fact_card 
        FOREIGN KEY (card_key) 
        REFERENCES dim_card(card_key),
    
    CONSTRAINT fk_fact_merchant 
        FOREIGN KEY (merchant_key) 
        REFERENCES dim_merchant(merchant_key)
);

CREATE INDEX idx_fact_date ON fact_transactions(date_key);
CREATE INDEX idx_fact_customer ON fact_transactions(customer_key);
CREATE INDEX idx_fact_card ON fact_transactions(card_key);
CREATE INDEX idx_fact_merchant ON fact_transactions(merchant_key);
CREATE INDEX idx_fact_amount ON fact_transactions(amount);
CREATE INDEX idx_fact_has_errors ON fact_transactions(has_errors);
CREATE INDEX idx_fact_fraud ON fact_transactions(is_fraud);
CREATE INDEX idx_fact_date_customer ON fact_transactions(date_key, customer_key);
CREATE INDEX idx_fact_date_merchant ON fact_transactions(date_key, merchant_key);
CREATE INDEX idx_fact_customer_card ON fact_transactions(customer_key, card_key);
CREATE INDEX idx_fact_date_amount ON fact_transactions(date_key, amount);

-- ========================================
-- VIEWS
-- ========================================

CREATE OR REPLACE VIEW vw_transaction_details AS
SELECT 
    f.transaction_id,
    d.full_date,
    d.year,
    d.month,
    d.quarter,
    c.customer_id,
    c.age_group,
    c.income_segment,
    c.credit_score_category,
    cd.card_brand,
    cd.card_type,
    cd.card_tier,
    cd.last_4_digits,  
    cd.card_on_dark_web,
    m.merchant_id,
    m.merchant_category_group,
    m.merchant_state,
    m.region,
    m.is_high_risk_mcc,
    f.amount,
    f.use_chip,
    f.has_errors,
    f.error_code,
    f.is_fraud
FROM fact_transactions f
    INNER JOIN dim_date d ON f.date_key = d.date_key
    INNER JOIN dim_customer c ON f.customer_key = c.customer_key
    INNER JOIN dim_card cd ON f.card_key = cd.card_key
    INNER JOIN dim_merchant m ON f.merchant_key = m.merchant_key;

CREATE OR REPLACE VIEW vw_daily_summary AS
SELECT 
    d.full_date,
    d.year,
    d.month,
    d.day_name,
    COUNT(*) as transaction_count,
    SUM(f.amount) as total_amount,
    AVG(f.amount) as avg_amount,
    MIN(f.amount) as min_amount,
    MAX(f.amount) as max_amount,
    SUM(CASE WHEN f.has_errors THEN 1 ELSE 0 END) as error_count,
    SUM(CASE WHEN f.use_chip THEN 1 ELSE 0 END) as chip_transactions,
    SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) as fraud_count
FROM fact_transactions f
    INNER JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.full_date, d.year, d.month, d.day_name
ORDER BY d.full_date DESC;

-- ========================================
-- FRAUD DETECTION VIEW
-- ========================================
-- Uses card_token to track suspicious patterns across transactions
-- without exposing actual card numbers
-- ========================================

CREATE OR REPLACE VIEW vw_suspicious_cards AS
SELECT 
    cd.card_token,
    cd.card_brand,
    cd.last_4_digits,
    cd.card_on_dark_web,
    COUNT(*) as transaction_count,
    SUM(f.amount) as total_amount,
    SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) as fraud_count,
    ROUND(100.0 * SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate
FROM fact_transactions f
    INNER JOIN dim_card cd ON f.card_key = cd.card_key
GROUP BY cd.card_token, cd.card_brand, cd.last_4_digits, cd.card_on_dark_web
HAVING SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) > 0
ORDER BY fraud_count DESC;


ANALYZE dim_date;
ANALYZE dim_customer;
ANALYZE dim_card;
ANALYZE dim_merchant;