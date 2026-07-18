# Real-Time Fraud Detection & Transaction Monitoring

## Project Overview

Financial fraud is rarely identified by a single suspicious transaction. It often appears as unusual customer behaviour, repeated fraud patterns across multiple transactions, or emerging trends within specific transaction channels and geographic regions.

This project builds a real-time fraud monitoring framework for a fictional retail bank, **Stratavax**, by combining transaction data, customer information, account details, fraud detection scores, and credit profiles into a unified reporting layer.

The objective is to help fraud analysts answer critical business questions such as:

> - Which transactions present the highest fraud risk?
> - Which customers require immediate investigation?
> - Which transaction channels contribute most to fraud?
> - How can fraud monitoring become more proactive rather than reactive?
> - How can data quality issues impact fraud reporting?

> **Note:** This project shares its dataset with the Credit Risk & Loan Default Analysis project in this portfolio. Both projects address different business problems and should be evaluated independently.

---

## Business Problem

Banks process thousands of transactions daily, making manual fraud investigations inefficient and difficult to scale.

Without centralized fraud monitoring, analysts face several challenges:

- Fraud indicators are spread across multiple systems.
- High-risk transactions are difficult to prioritize.
- Customer-level fraud patterns can go unnoticed.
- Portfolio-level fraud trends are difficult to monitor.
- Data quality issues can silently distort fraud metrics.

This project addresses these challenges by creating a single source of truth for fraud monitoring and implementing a risk-based alert framework for investigators.

---

## Dataset

The project uses a synthetic banking dataset consisting of approximately 3,000 records across five related tables.

| Table | Description |
|-------|------------|
| bank_customers | Customer demographic and income information |
| bank_accounts | Customer account information |
| bank_transactions | Transaction-level banking activities |
| fraud_detection | Fraud flags and fraud scores |
| credit_scores | Customer credit risk classifications |

### Portfolio Relationships

```

                    BANK CUSTOMERS
                           |
                           |
                           |
                    BANK ACCOUNTS
                           |
                           |
                           |
                   BANK TRANSACTIONS
                           |
                           |
                  ---------------------
                  |                   |
                  ↓                   ↓
            FRAUD DETECTION      CREDIT SCORES
                  |                   |
                  ---------------------
                           |
                           ↓
                    v_fraud_master
                     (Master View)
                           |
                           |
                           ↓
                    Fraud Monitoring
                           |
        ------------------------------------------------
        |                     |                        |
        ↓                     ↓                        ↓
   Fraud Rates         Risk Scoring            Customer Watchlist
     Analysis         (High/Medium/Low)        (>3 Fraud Cases)
        |                     |                        |
        ------------------------------------------------
                           |
                           ↓
                     High Risk Alerts
                           |
                           ↓
                 Business Recommendations


```

---

## Technologies Used

- SQL Server (T-SQL)
- SQL Views
- Common Table Expressions (CTEs)
- CASE Statements
- Aggregate Functions
- Fraud Risk Analysis
- Data Validation Techniques
- Behavioral Analysis
- Risk Segmentation
- Transaction Monitoring

---

## Methodology

The project follows a layered fraud monitoring approach.

### Data Validation

Before any analysis was performed, the dataset was validated for:

- Duplicate transaction IDs
- Missing fraud records
- Orphaned transactions
- Invalid transaction amounts
- Join integrity across all tables

### Data Modeling

A master reporting view (`v_fraud_master`) was created by joining:

- Customers
- Accounts
- Transactions
- Fraud scores
- Credit profiles

This creates a reusable reporting layer for all downstream analyses.

### Behavioral Analysis

Customer spending behaviour was profiled using:

- Average transaction values
- Maximum transaction values
- Transaction frequencies

Transactions are then evaluated against these behavioral baselines to identify anomalies.

### Risk Scoring Framework

Fraud risk is determined using multiple signals, including:

- Fraud scores
- Transaction amounts
- Customer credit profiles

Transactions are classified as:

- High Risk
- Medium Risk
- Low Risk

High-risk transactions are automatically surfaced through an alert feed for investigators.

---

## KPIs Developed

This project includes:

- Portfolio Fraud Rate Analysis
- Fraud Rate by Transaction Type
- Fraud Rate by Country
- Customer-Level Fraud Watchlists
- High-Risk Transaction Alerts
- Behavioral Anomaly Detection
- Risk Segmentation Analysis
- Customer Spending Analysis
- Transaction Monitoring Reports
- Risk Scoring Framework

---

## Data Quality Challenges Solved

### Incorrect Fraud Counts

The original implementation counted every transaction instead of counting only confirmed fraud cases.

#### Problem

```sql
COUNT(fraud_flag)
```

This counted both:

- Fraudulent transactions
- Legitimate transactions

#### Solution

```sql
SUM(fraud_flag)
```

This correctly counts only confirmed fraud cases.

---

### Duplicate Risk Scoring Logic

Risk classifications were implemented separately across multiple KPIs.

#### Solution

A centralized CTE was introduced to provide:

- Consistent risk classifications
- Easier maintenance
- Improved scalability

---

### Incomplete Data Validation

Additional validation checks were implemented for:

- Duplicate transactions
- Missing fraud records
- Invalid transaction amounts
- Broken relationships between tables

These checks ensure that portfolio-level fraud metrics remain reliable.

---

## Key Insights

The analysis revealed that:

- Fraud is not evenly distributed across customer segments.
- Certain transaction channels exhibit higher fraud rates than others.
- Customer-level fraud patterns are easier to identify when analyzed collectively rather than transaction-by-transaction.
- Behavioral baselines provide better anomaly detection than static thresholds.
- Data quality issues can significantly distort fraud reporting if left unchecked.

The portfolio fraud rate within this synthetic dataset is approximately **4.5%**, representing roughly **134 fraudulent transactions**.

> **Note:** This fraud rate is intentionally higher than real-world banking environments to provide sufficient cases for analytical purposes.

---

## Business Recommendations

- Prioritize investigations using High-Risk Alert feeds.
- Monitor customer-level fraud patterns continuously.
- Incorporate fraud rates alongside raw transaction counts.
- Use anomaly detection as an investigation tool rather than an automated approval or rejection mechanism.
- Perform regular portfolio-level fraud monitoring across transaction channels and geographic regions.

---

## Business Impact

This framework provides fraud investigators with:

- Faster identification of suspicious transactions.
- Centralized fraud monitoring capabilities.
- Improved portfolio-level fraud visibility.
- Reliable customer watchlists for repeated fraud cases.
- Better prioritization of investigative efforts.
- Consistent and maintainable risk scoring logic.

---

## Skills Demonstrated

This project demonstrates proficiency in:

- Advanced SQL
- Fraud Analytics
- Data Modeling
- Transaction Monitoring
- Risk Segmentation
- Behavioral Analysis
- Data Validation
- Financial Analytics
- Business Intelligence Reporting
- Problem Solving
- Decision Support Systems

---

## Project Deliverables

- Fraud Monitoring Framework
- High-Risk Alert System
- Customer Fraud Watchlists
- Behavioral Anomaly Detection
- Fraud Risk Scoring
- Portfolio Fraud Analysis
- SQL Reporting Views
- Data Quality Validation Checks
- Business Recommendations

---

## Results

The final solution delivers a scalable fraud monitoring framework capable of transforming raw banking transactions into actionable fraud intelligence.

By centralizing fraud data and implementing risk-based monitoring techniques, the project provides:

- Accurate fraud reporting.
- Reliable high-risk transaction alerts.
- Improved customer-level fraud visibility.
- Enhanced portfolio monitoring capabilities.
- A reusable foundation for future real-time fraud detection and predictive analytics initiatives.

---

> **Disclaimer:** The fraud scoring model implemented in this project is a rule-based analytical framework designed for educational and portfolio purposes. It is intended to support fraud investigations and should not be considered a production-grade machine learning fraud detection system.
