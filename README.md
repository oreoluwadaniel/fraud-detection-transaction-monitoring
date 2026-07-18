# Real-time fraud detection and transaction monitoring

SQL project for a fictional bank, Stratavax. Built in T-SQL (SQL Server). This project stands on its own. It shares a dataset with a second project in this portfolio, a credit risk and loan default analysis, but the two ask different questions and should be read separately.

The full script is in [fraud-detection-monitoring.sql](./fraud-detection-monitoring.sql).

## Business problem

A bank the size of Stratavax processes thousands of transactions a day, and fraud does not announce itself. It shows up as a withdrawal that is way bigger than what a customer normally does, a spike in fraud reports from one country, or a customer who has had three flagged transactions this month and nobody noticed because the cases were spread across different analysts.

The fraud team's actual problem is not "we need more data." It is "we have data scattered across five tables and no single place to see who to look at first." Without that, investigators spend their time hunting for information instead of investigating. Real fraud sits in the queue longer than it should, and by the time someone gets to it, the money is often already gone.

This script builds that single place to look. It pulls transaction, account, customer, fraud, and credit data into one view, then layers business logic on top of it so the highest risk activity rises to the top automatically instead of getting buried in a spreadsheet.

## Data source

This is a synthetic dataset built to mirror what a retail bank's core systems would actually hold, roughly 3,000 records in each of five related tables:

- **bank_customers**: customer_id, name, age, country, income
- **bank_accounts**: account_id, customer_id, bank_name, account_type, balance, open_date
- **bank_transactions**: transaction_id, account_id, transaction_type, amount, transaction_date
- **fraud_detection**: transaction_id, fraud_flag, fraud_score
- **credit_scores**: customer_id, credit_score, risk_band

The tables connect the way you would expect in a real bank: a customer can hold multiple accounts, an account can have many transactions, and every transaction has exactly one entry in the fraud detection feed with a flag (0 or 1) and a model generated fraud score. Customers are spread across five countries with income and credit profiles that look plausible rather than randomly generated. It is not real customer data, but the structure and the relationships between tables are realistic enough to build a genuine analysis on top of.

## Methodology

I worked through this the way I would on a real fraud team, in order:

**Data validation first.** Before writing a single KPI, I checked that the data could actually be trusted. Row counts, whether every transaction had a matching account, whether any transaction ID showed up more than once, whether every transaction had a corresponding fraud record, and whether any amounts were zero or negative. Skipping this step is how you end up presenting a fraud rate that is wrong because of a data quality issue nobody caught.

**One reporting view, not five separate queries.** I built a single view, `v_fraud_master`, that joins transactions to accounts, customers, fraud records, and credit scores. Every KPI after that reads from this one view instead of repeating the same five-table join over and over. That matters for two reasons: it is less code to maintain, and everyone on the team is working from the same definition of "a transaction" instead of six slightly different versions of it.

**Behavioral baseline before flagging anomalies.** You cannot say a transaction looks unusual for a customer until you know what usual looks like for that customer. So before flagging anything as an anomaly, I built a profile of each customer's average and maximum transaction size. Then the anomaly check compares new activity against that baseline instead of against some arbitrary bank-wide number that would flag a wealthy customer's normal spending as suspicious and miss a lower-income customer's actual fraud.

**Layered risk scoring.** Fraud risk is not one number, it is a mix of signals: the model's own fraud score, the transaction size, and the customer's credit profile. The scoring logic in this script combines all three into a single High, Medium, or Low Risk label, then filters that down to a live alert list of just the High Risk cases.

## Analysis and error check

I went through every KPI in the original script line by line before calling it finished. Two real issues turned up, plus a few things worth tightening.

**The high-risk customer count was wrong.** KPI 6 was supposed to find customers with more than 3 confirmed fraud cases. The original SQL used `COUNT(fraud_flag)`, which counts every transaction that has a matching row in the fraud_detection table, whether that row says the transaction was fraudulent or not. Since every transaction gets a fraud record (flagged 0 or 1), this was effectively counting total transaction volume per customer, not fraud cases. A customer with 10 clean transactions and zero fraud would have tripped the "more than 3" threshold just as easily as someone with 4 actual fraud cases. I changed it to `SUM(fraud_flag)`, which only adds up the transactions actually marked fraudulent. This is the difference between a useful watchlist and a list of your most active customers.

**Data validation was too thin.** The original Step 1 checked a row count and previewed 10 rows. That is not validation, that is a glance. I added checks for orphaned transactions (no matching account), duplicate transaction IDs, transactions with no fraud record at all, and non-positive transaction amounts. None of these turned up in this dataset, which is good news, but the checks now exist so the next person who runs this against live production data will actually catch a problem if one shows up.

**The risk scoring logic was written twice.** KPI 8 (the full risk scoring output) and KPI 9 (the high-risk alert feed) each had their own copy of the same CASE statement defining High, Medium, and Low Risk. That works fine until someone updates the thresholds in one place and forgets the other, and now your dashboard and your alert queue disagree with each other. I pulled the scoring logic into a single CTE that both queries now read from.

**Fraud rate needed a denominator.** KPI 5 showed raw fraud counts by transaction type, which makes the highest-volume channel look like the riskiest one even if its fraud rate is actually low. I added a fraud rate column next to the raw count so the comparison is fair across channels.

One thing I want to flag rather than fix: the anomaly check in KPI 4 compares each transaction against a customer's average, and that average includes the transaction being tested. That is a common shortcut in a first pass, and it is fine for this purpose, but it means the "3x average" threshold is slightly harder to trip than it looks, especially for customers with few transactions. Worth knowing if this logic ever gets used to make real decisions.

## Insight

Running the corrected queries against this dataset shows a portfolio fraud rate of about 4.5 percent, or 134 flagged transactions out of roughly 3,000. That is high for a real bank (production fraud rates are usually a small fraction of a percent), which tells me this dataset was built to have enough fraud cases to actually analyze, not to mirror real-world rarity. Worth calling out clearly in any presentation of this work so nobody mistakes a demo number for a production benchmark.

More useful than the headline rate is where the risk clusters. Fraud is not spread evenly. Certain transaction types and certain countries show meaningfully more flagged activity than others once you look at rate instead of raw count, and a handful of customers show up in the KPI 6 watchlist with more than 3 confirmed fraud cases each, which is exactly the kind of pattern that gets missed when fraud investigators are working transaction by transaction instead of customer by customer.

## Recommendation

Stand up the high-risk alert feed (KPI 9) as something investigators check first thing, not something they stumble into. A queue sorted by risk level beats a queue sorted by "whatever came in most recently," because it puts the transactions most likely to be real fraud in front of a human fastest.

Use the KPI 6 watchlist to shift from reacting to individual transactions to managing customer relationships. A customer with repeated fraud flags deserves account level review, maybe a call, maybe extra verification steps on future transactions, not just having each incident closed out one at a time as if it were unrelated to the last one.

Treat the anomaly detection logic in KPI 4 as a first filter, not a final answer. It is good at surfacing transactions worth a second look. It is not sophisticated enough to make an automatic block or approve decision on its own.

## Business impact

A single source of truth for fraud data means less time spent reconciling numbers between teams and more time spent actually investigating. Faster identification of the highest risk transactions and customers means fewer cases sitting untouched while losses accrue. And because the scoring logic now lives in one place, thresholds can be adjusted as fraud patterns shift without hunting through multiple copies of the same code to update them all.

## What was done

I reviewed the original script end to end, tested the join logic against the actual data (not just against how it reads on the page), found and fixed a real counting bug in the high-risk customer KPI, strengthened the data validation step, removed duplicated scoring logic, and added a fraud rate metric where raw counts alone would have been misleading. The corrected script is in this folder, with inline comments explaining every change and why it mattered.

## Tools used and how they helped

**SQL Server (T-SQL)** for everything: building the reporting view, writing the KPIs, and structuring the risk scoring logic with CASE statements and a CTE. T-SQL specific syntax like `TOP` and `CAST` shows up throughout, so this script is written for SQL Server or Azure SQL, not a drop-in for MySQL or PostgreSQL without small syntax adjustments.

**Views** to centralize the join logic once instead of repeating a five-table join in every query. This is the difference between a script that is easy to maintain and one where a schema change means editing eleven separate places.

**CTEs (common table expressions)** to build the customer spending baseline in KPI 4 and to share the risk scoring logic between KPI 8 and KPI 9, instead of nesting nested subqueries that get hard to read past two levels deep.

**CASE statements** to turn raw numbers into business language. A fraud score of 0.87 does not mean anything to a branch manager. "High Risk" does.

## Results

A working, corrected fraud monitoring script that takes five raw tables and turns them into a portfolio fraud rate, a live high-risk alert feed, a customer level watchlist, and a geographic and channel breakdown of where fraud is concentrated. One real logic bug fixed, data validation strengthened, and duplicated code consolidated into a single source of truth for risk scoring.
