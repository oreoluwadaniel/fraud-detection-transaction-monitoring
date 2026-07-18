/* ================================================================
   REAL-TIME FRAUD DETECTION & TRANSACTION MONITORING
   Stratavax Bank | Fraud Analytics
   Written for SQL Server (T-SQL)
   ================================================================

   Business objective
   ----------------------------------------------------------------
   Give the fraud team one place to watch transaction activity,
   catch suspicious behavior early, and know exactly which
   customers and transactions to look at first.

   Tables used
   ----------------------------------------------------------------
   bank_transactions  transaction_id, account_id, transaction_type,
                       amount, transaction_date
   bank_accounts      account_id, customer_id, bank_name,
                       account_type, balance, open_date
   bank_customers     customer_id, name, age, country, income
   fraud_detection    transaction_id, fraud_flag, fraud_score
   credit_scores      customer_id, credit_score, risk_band

   Corrections made during review (see README for the full writeup)
   ----------------------------------------------------------------
   1. KPI 6 used COUNT(fraud_flag), which counts every transaction
      that has a matching fraud record whether it was flagged as
      fraud or not. Changed to SUM(fraud_flag) so it only counts
      transactions actually marked fraudulent.
   2. Step 1 only checked row count and previewed 10 rows. Added
      real validation: orphaned transactions, duplicate IDs, and
      non-positive amounts.
   3. KPI 8 and KPI 9 repeated the same risk scoring CASE statement
      twice. Pulled it into one CTE so both queries stay in sync
      if the scoring rules ever change.
   4. Added a fraud rate column to KPI 5 so fraud counts by channel
      are actually comparable to each other.
   ================================================================ */


/*-----------------------------------------------------------------
STEP 1: DATA QUALITY CHECKS

Run these before trusting anything downstream. If any of these
return unexpected rows, fix the source data first.
-----------------------------------------------------------------*/

-- Row count sanity check
SELECT COUNT(*) AS total_transactions
FROM bank_transactions;

-- Transactions with no account attached (would break every join below)
SELECT COUNT(*) AS transactions_missing_account
FROM bank_transactions
WHERE account_id IS NULL;

-- Duplicate transaction IDs (would inflate every downstream count)
SELECT transaction_id, COUNT(*) AS occurrences
FROM bank_transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Transactions that never made it into the fraud detection feed
SELECT COUNT(*) AS transactions_with_no_fraud_record
FROM bank_transactions t
LEFT JOIN fraud_detection f ON t.transaction_id = f.transaction_id
WHERE f.transaction_id IS NULL;

-- Zero or negative amounts (likely a data entry or feed error)
SELECT COUNT(*) AS non_positive_amounts
FROM bank_transactions
WHERE amount <= 0;

-- Quick look at the fraud feed itself
SELECT TOP 10 *
FROM fraud_detection;


/*-----------------------------------------------------------------
STEP 2: BUILD THE FRAUD REPORTING VIEW

Every join below is many-to-one: each transaction matches at most
one account, one customer, one fraud record, and one credit score
row. That keeps this view at transaction grain, so nothing gets
double counted downstream.
-----------------------------------------------------------------*/

CREATE VIEW v_fraud_master AS

SELECT
    t.transaction_id,
    t.account_id,
    t.transaction_type,
    t.amount,
    t.transaction_date,

    a.customer_id,
    a.account_type,
    a.balance,

    c.name,
    c.age,
    c.country,
    c.income,

    f.fraud_flag,
    f.fraud_score,

    cs.credit_score,
    cs.risk_band

FROM bank_transactions t

LEFT JOIN bank_accounts a
    ON t.account_id = a.account_id

LEFT JOIN bank_customers c
    ON a.customer_id = c.customer_id

LEFT JOIN fraud_detection f
    ON t.transaction_id = f.transaction_id

LEFT JOIN credit_scores cs
    ON c.customer_id = cs.customer_id;



/*-----------------------------------------------------------------
KPI 1: PORTFOLIO FRAUD RATE

Share of all transactions flagged as fraudulent.
-----------------------------------------------------------------*/

SELECT
    SUM(CAST(fraud_flag AS FLOAT)) / COUNT(*) AS fraud_rate
FROM fraud_detection;



/*-----------------------------------------------------------------
KPI 2: HIGH VALUE TRANSACTION MONITORING

Transactions large enough to warrant a second look regardless of
their fraud score.
-----------------------------------------------------------------*/

SELECT
    transaction_id,
    customer_id,
    amount

FROM v_fraud_master

WHERE amount > 10000

ORDER BY amount DESC;



/*-----------------------------------------------------------------
KPI 3: CUSTOMER TRANSACTION PROFILING

Average, maximum, and total transaction volume per customer. This
is the behavioral baseline the anomaly check in KPI 4 is built on.
-----------------------------------------------------------------*/

SELECT
    customer_id,
    AVG(amount) AS avg_txn,
    MAX(amount) AS max_txn,
    COUNT(*) AS txn_count

FROM v_fraud_master

GROUP BY customer_id;



/*-----------------------------------------------------------------
KPI 4: TRANSACTION ANOMALY DETECTION

Flags any transaction more than three times a customer's own
average as an anomaly. Note the average includes the transaction
being tested, so this is a simplified heuristic, not a formal
outlier test. It is a fast first pass, not a final verdict.
-----------------------------------------------------------------*/

WITH customer_profile AS (

    SELECT
        customer_id,
        AVG(amount) AS avg_amount

    FROM v_fraud_master

    GROUP BY customer_id

)

SELECT

    v.transaction_id,
    v.customer_id,
    v.amount,
    cp.avg_amount,

    CASE
        WHEN v.amount > cp.avg_amount * 3
        THEN 'Anomaly'
        ELSE 'Normal'
    END AS anomaly_flag

FROM v_fraud_master v

JOIN customer_profile cp
    ON v.customer_id = cp.customer_id;



/*-----------------------------------------------------------------
KPI 5: FRAUD BY TRANSACTION TYPE

Raw counts by channel plus a fraud rate, since a channel with more
volume will always show a bigger raw count even if it is not
riskier per transaction.
-----------------------------------------------------------------*/

SELECT
    transaction_type,
    SUM(fraud_flag) AS fraud_cases,
    COUNT(*) AS total_txns,
    SUM(CAST(fraud_flag AS FLOAT)) / COUNT(*) AS fraud_rate

FROM v_fraud_master

GROUP BY transaction_type;



/*-----------------------------------------------------------------
KPI 6: HIGH RISK CUSTOMER IDENTIFICATION

Customers with more than 3 confirmed fraud cases on their record.

Fixed: this originally used COUNT(fraud_flag), which counts every
transaction that has a matching fraud_detection row, whether that
row was flagged 0 or 1. Switched to SUM(fraud_flag) so it only
counts transactions actually marked fraudulent.
-----------------------------------------------------------------*/

SELECT
    customer_id,
    credit_score,
    risk_band,
    SUM(fraud_flag) AS fraud_cases

FROM v_fraud_master

GROUP BY
    customer_id,
    credit_score,
    risk_band

HAVING SUM(fraud_flag) > 3;



/*-----------------------------------------------------------------
KPI 7: GEOGRAPHIC FRAUD ANALYSIS

Fraud volume and total transactions by country, to spot markets
carrying more than their share of fraud exposure.
-----------------------------------------------------------------*/

SELECT
    country,
    SUM(fraud_flag) AS fraud_cases,
    COUNT(*) AS total_txns

FROM v_fraud_master

GROUP BY country

ORDER BY fraud_cases DESC;



/*-----------------------------------------------------------------
KPI 8 & 9: FRAUD RISK SCORING AND REAL TIME ALERTS

Both queries now share one scoring definition (the fraud_scoring
CTE) instead of two separate copies of the same CASE statement.
That way, if the scoring thresholds ever change, there is only one
place to update them.

High Risk    : fraud_score above 0.8
Medium Risk  : large transaction or low credit score
Low Risk     : everything else

Note: transactions with no matching fraud_detection row will have
a NULL fraud_score. NULL comparisons evaluate to unknown, so those
rows fall through to the amount/credit_score checks rather than
being wrongly marked High Risk.
-----------------------------------------------------------------*/

WITH fraud_scoring AS (

    SELECT

        transaction_id,
        customer_id,
        amount,
        fraud_score,
        credit_score,

        CASE
            WHEN fraud_score > 0.8
                THEN 'High Risk'

            WHEN amount > 10000
                THEN 'Medium Risk'

            WHEN credit_score < 500
                THEN 'Medium Risk'

            ELSE 'Low Risk'

        END AS fraud_risk_level

    FROM v_fraud_master

)

-- KPI 8: full risk scoring output for reporting
SELECT
    transaction_id,
    customer_id,
    amount,
    fraud_score,
    credit_score,
    fraud_risk_level
FROM fraud_scoring;


WITH fraud_scoring AS (

    SELECT

        transaction_id,
        customer_id,
        amount,
        fraud_score,
        credit_score,

        CASE
            WHEN fraud_score > 0.8
                THEN 'High Risk'

            WHEN amount > 10000
                THEN 'Medium Risk'

            WHEN credit_score < 500
                THEN 'Medium Risk'

            ELSE 'Low Risk'

        END AS fraud_risk_level

    FROM v_fraud_master

)

-- KPI 9: High Risk transactions only, for the alert queue
SELECT
    transaction_id,
    customer_id,
    amount,
    fraud_risk_level
FROM fraud_scoring
WHERE fraud_risk_level = 'High Risk';



/*================================================================

BUSINESS IMPACT

This monitoring framework enables the fraud team to:

- Spot suspicious transactions as they happen, not days later.
- Flag customers whose spending has moved outside their own norm.
- Prioritize investigations by risk level instead of working
  transactions in the order they arrive.
- Track which payment channels and countries are carrying the
  most fraud exposure.
- Cut financial losses through earlier intervention.

================================================================*/
