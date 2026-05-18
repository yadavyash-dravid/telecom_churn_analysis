/* ============================================================
   MAVEN TELECOM — CUSTOMER CHURN ANALYSIS
   Author      : Yash Yadav
   Database    : SQL Server
   Dataset     : telecom_customer_churn
   Objective   : Understand why customers are leaving Maven Telecom,
                 identify high-risk active customers, and quantify
                 the revenue impact of churn.
   ============================================================
   TABLE OF CONTENTS
   -----------------
   01  Data Validation
   02  Overview KPIs
   03  Revenue Impact
   04  Churn by Geography
   05  Churn by Demographics
   06  Churn by Contract & Offers
   07  Churn by Services
   08  Churn by Tenure
   09  Churn Reasons & Categories
   10  Payment Method Analysis      
   11  Offer Effectiveness          
   12  Geographic Revenue Breakdown  
   13  Contract Value Comparison     
   14  Retention Risk Scoring (Active Customers)
   15  Executive Summary CTE         
   ============================================================ */


/* ============================================================
   01  DATA VALIDATION
   Purpose : Confirm data integrity.
   ============================================================ */

-- Total unique customers in the dataset
SELECT
    COUNT(DISTINCT Customer_ID) AS total_customers
FROM telecom_customer_churn;


-- Check for duplicate Customer IDs (should return 0 rows if data is clean)
SELECT
    Customer_ID,
    COUNT(Customer_ID) AS duplicate_count
FROM telecom_customer_churn
GROUP BY Customer_ID
HAVING COUNT(Customer_ID) > 1;


-- Check for NULL values in critical columns
SELECT
    SUM(CASE WHEN Customer_ID          IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN Customer_Status      IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN Monthly_Charge       IS NULL THEN 1 ELSE 0 END) AS null_monthly_charge,
    SUM(CASE WHEN Total_Revenue        IS NULL THEN 1 ELSE 0 END) AS null_total_revenue,
    SUM(CASE WHEN Churn_Reason         IS NULL THEN 1 ELSE 0 END) AS null_churn_reason,
    SUM(CASE WHEN Tenure_in_Months     IS NULL THEN 1 ELSE 0 END) AS null_tenure
FROM telecom_customer_churn;


/* ============================================================
   02  OVERVIEW KPIs
   Purpose : Establish the overall baseline — total customers,
             churn rate, and customer distribution by status.
   ============================================================ */

-- Overall churn rate and customer distribution by status
SELECT
    Customer_Status,
    COUNT(*)                                                          AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)                AS percentage
FROM telecom_customer_churn
GROUP BY Customer_Status;


/* ============================================================
   03  REVENUE IMPACT
   Purpose : Quantify how much revenue was lost to churners
             vs retained and newly joined customers.
   ============================================================ */

-- Revenue by customer status (absolute + percentage share)
SELECT
    Customer_Status,
    COUNT(Customer_ID)                                                            AS customer_count,
    CEILING(SUM(Total_Revenue))                                                   AS total_revenue,
    ROUND(
        SUM(Total_Revenue) * 100.0 /
        (SELECT SUM(Total_Revenue) FROM telecom_customer_churn), 1
    )                                                                             AS revenue_percentage
FROM telecom_customer_churn
GROUP BY Customer_Status;


-- Revenue lost specifically to churned customers
SELECT
    CEILING(SUM(Total_Revenue))                                                   AS total_revenue_lost,
    COUNT(Customer_ID)                                                            AS total_churned_customers,
    CEILING(AVG(Monthly_Charge))                                                  AS avg_monthly_charge_churner
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned';


/* ============================================================
   04  CHURN BY GEOGRAPHY
   Purpose : Identify cities with disproportionately high churn.
             Filter to cities with >30 customers for statistical
             significance (avoids small-sample distortion).
   Tableau  : Map chart or bar chart sorted by churn rate.
   ============================================================ */

-- Top 4 cities by churn rate (min 30 customers per city)
SELECT TOP 4
    City,
    COUNT(Customer_ID)                                                            AS total_customers,
    COUNT(CASE WHEN Customer_Status = 'Churned' THEN Customer_ID END)             AS churned,
    CEILING(
        COUNT(CASE WHEN Customer_Status = 'Churned' THEN Customer_ID END) * 100.0
        / COUNT(Customer_ID)
    )                                                                             AS churn_rate_pct
FROM telecom_customer_churn
GROUP BY City
HAVING
    COUNT(Customer_ID) > 30
    AND COUNT(CASE WHEN Customer_Status = 'Churned' THEN Customer_ID END) > 0
ORDER BY churn_rate_pct DESC;


/* ============================================================
   05  CHURN BY DEMOGRAPHICS
   Purpose : Profile who churned — age, gender, marital status,
             dependents, and referral behaviour.
   ============================================================ */

-- Churn by age group
SELECT
    CASE
        WHEN Age <= 30 THEN '19–30 yrs'
        WHEN Age <= 40 THEN '31–40 yrs'
        WHEN Age <= 50 THEN '41–50 yrs'
        WHEN Age <= 60 THEN '51–60 yrs'
        ELSE                 '> 60 yrs'
    END                                                                           AS age_group,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY
    CASE
        WHEN Age <= 30 THEN '19–30 yrs'
        WHEN Age <= 40 THEN '31–40 yrs'
        WHEN Age <= 50 THEN '41–50 yrs'
        WHEN Age <= 60 THEN '51–60 yrs'
        ELSE                 '> 60 yrs'
    END
ORDER BY churn_pct DESC;


-- Churn by gender
SELECT
    Gender,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Gender
ORDER BY churn_pct DESC;


-- Churn by marital status
SELECT
    Married,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Married
ORDER BY churn_pct DESC;


-- Churn by dependents (grouped flag)
SELECT
    CASE
        WHEN Number_of_Dependents > 0 THEN 'Has Dependents'
        ELSE                               'No Dependents'
    END                                                                           AS dependents,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY
    CASE
        WHEN Number_of_Dependents > 0 THEN 'Has Dependents'
        ELSE                               'No Dependents'
    END
ORDER BY churn_pct DESC;


-- Churn by referral behaviour (did they refer anyone before leaving?)
SELECT
    CASE
        WHEN Number_of_Referrals > 0 THEN 'Gave Referrals'
        ELSE                              'No Referrals'
    END                                                                           AS referral_status,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY
    CASE
        WHEN Number_of_Referrals > 0 THEN 'Gave Referrals'
        ELSE                              'No Referrals'
    END;


/* ============================================================
   06  CHURN BY CONTRACT & OFFERS
   Purpose : Understand which contract types and promotional
             offers are associated with higher churn.
   ============================================================ */

-- Churn by contract type
SELECT
    Contract,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Contract
ORDER BY churned DESC;


-- Churn distribution across offers (which offer failed to retain customers?)
SELECT
    Offer,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Offer
ORDER BY churn_pct DESC;


/* ============================================================
   07  CHURN BY SERVICES
   Purpose : Determine which services (internet type, tech
             support, phone, streaming) were most common among
             churners, and specifically among competitor churners.
   ============================================================ */

-- Churn by internet type (all churners)
SELECT
    Internet_Type,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Internet_Type
ORDER BY churned DESC;


-- Churn by internet type filtered to competitor-driven churners
-- Insight: reveals which internet type is most at risk from competitors
SELECT
    Internet_Type,
    Churn_Category,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
  AND Churn_Category = 'Competitor'
GROUP BY Internet_Type, Churn_Category
ORDER BY churn_pct DESC;


-- Churn by premium tech support (no support = higher churn?)
SELECT
    Premium_Tech_Support,
    COUNT(Customer_ID)                                                            AS churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Premium_Tech_Support
ORDER BY churned DESC;


-- Churn by phone service subscription
SELECT
    Phone_Service,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Phone_Service;


-- Churn by internet service subscription
SELECT
    Internet_Service,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Internet_Service;


/* ============================================================
   08  CHURN BY TENURE
   Purpose : Understand at what stage of the customer lifecycle
             churn is most likely. Also profiles new joiners.
   ============================================================ */

-- Churn distribution by tenure band
SELECT
    CASE
        WHEN Tenure_in_Months <= 6  THEN '0–6 months'
        WHEN Tenure_in_Months <= 12 THEN '7–12 months'
        WHEN Tenure_in_Months <= 24 THEN '1–2 years'
        ELSE                             '> 2 years'
    END                                                                           AS tenure_band,
    COUNT(Customer_ID)                                                            AS churned,
    CEILING(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER())         AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY
    CASE
        WHEN Tenure_in_Months <= 6  THEN '0–6 months'
        WHEN Tenure_in_Months <= 12 THEN '7–12 months'
        WHEN Tenure_in_Months <= 24 THEN '1–2 years'
        ELSE                             '> 2 years'
    END
ORDER BY churned DESC;


-- Typical tenure of newly joined customers (onboarding health check)
SELECT
    Customer_Status,
    CASE
        WHEN Tenure_in_Months <= 1  THEN '1 Month'
        WHEN Tenure_in_Months <= 6  THEN '1–6 Months'
        WHEN Tenure_in_Months <= 12 THEN '1 Year'
        WHEN Tenure_in_Months <= 24 THEN '1–2 Years'
        ELSE                             '> 2 Years'
    END                                                                           AS tenure_band,
    COUNT(Customer_ID)                                                            AS customer_count
FROM telecom_customer_churn
WHERE Customer_Status = 'Joined'
GROUP BY
    Customer_Status,
    CASE
        WHEN Tenure_in_Months <= 1  THEN '1 Month'
        WHEN Tenure_in_Months <= 6  THEN '1–6 Months'
        WHEN Tenure_in_Months <= 12 THEN '1 Year'
        WHEN Tenure_in_Months <= 24 THEN '1–2 Years'
        ELSE                             '> 2 Years'
    END;


/* ============================================================
   09  CHURN REASONS & CATEGORIES
   Purpose : Drill into exact reasons customers left.
             Churn_Category gives the bucket (Competitor,
             Dissatisfaction, etc.), Churn_Reason gives the
             specific reason within that bucket.
   ============================================================ */

-- Top 10 specific churn reasons with category context
SELECT TOP 10
    Churn_Reason,
    Churn_Category,
    COUNT(Customer_ID)                                                            AS total_churned,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 2)        AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
  AND Churn_Reason IS NOT NULL
GROUP BY Churn_Reason, Churn_Category
ORDER BY total_churned DESC;


-- Revenue lost per churn category
-- Insight: even a small % category could mean large revenue loss
SELECT
    Churn_Category,
    ROUND(SUM(Total_Revenue), 0)                                                  AS revenue_lost,
    CEILING(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER())         AS churn_pct
FROM telecom_customer_churn
WHERE Customer_Status = 'Churned'
GROUP BY Churn_Category
ORDER BY churn_pct DESC;


/* ============================================================
   10  PAYMENT METHOD ANALYSIS                          ← NEW
   Purpose : Examine whether payment method correlates with
             churn. Electronic check users are often flagged
             as higher risk in telecom datasets.
   ============================================================ */

-- Churn rate by payment method (churners vs total per method)
SELECT
    Payment_Method,
    COUNT(Customer_ID)                                                            AS total_customers,
    SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END)                 AS churned,
    ROUND(
        SUM(CASE WHEN Customer_Status = 'Churned' THEN 1.0 ELSE 0 END)
        / COUNT(Customer_ID) * 100, 1
    )                                                                             AS churn_rate_pct,
    ROUND(AVG(Monthly_Charge), 2)                                                 AS avg_monthly_charge
FROM telecom_customer_churn
GROUP BY Payment_Method
ORDER BY churn_rate_pct DESC;


/* ============================================================
   11  OFFER EFFECTIVENESS                              ← NEW
   Purpose : Compare how well each offer retains customers.
             Which offers correlate with staying vs churning?
   ============================================================ */

-- Retention rate per offer (stayed vs churned breakdown)
SELECT
    Offer,
    COUNT(Customer_ID)                                                            AS total_customers,
    SUM(CASE WHEN Customer_Status = 'Stayed'  THEN 1 ELSE 0 END)                 AS stayed,
    SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END)                 AS churned,
    ROUND(
        SUM(CASE WHEN Customer_Status = 'Stayed' THEN 1.0 ELSE 0 END)
        / COUNT(Customer_ID) * 100, 1
    )                                                                             AS retention_rate_pct
FROM telecom_customer_churn
GROUP BY Offer
ORDER BY retention_rate_pct DESC;


/* ============================================================
   12  GEOGRAPHIC REVENUE BREAKDOWN                    ← NEW
   Purpose : Identify which cities contribute the most revenue
             and which are losing it to churn. Useful for
             prioritising regional retention campaigns.
   ============================================================ */

-- Revenue by city — total earned vs lost to churn (top 10 cities)
SELECT TOP 10
    City,
    COUNT(Customer_ID)                                                            AS total_customers,
    CEILING(SUM(Total_Revenue))                                                   AS total_revenue,
    CEILING(SUM(CASE WHEN Customer_Status = 'Churned' THEN Total_Revenue ELSE 0 END)) AS revenue_lost,
    ROUND(
        SUM(CASE WHEN Customer_Status = 'Churned' THEN Total_Revenue ELSE 0 END)
        / SUM(Total_Revenue) * 100, 1
    )                                                                             AS revenue_loss_pct
FROM telecom_customer_churn
GROUP BY City
HAVING COUNT(Customer_ID) > 30
ORDER BY revenue_lost DESC;


/* ============================================================
   13  CONTRACT VALUE COMPARISON                       ← NEW
   Purpose : Compare the average revenue, tenure, and monthly
             charge across contract types. Shows the long-term
             business value difference between contract tiers.
   ============================================================ */

-- Average customer value by contract type (all statuses)
SELECT
    Contract,
    COUNT(Customer_ID)                                                            AS total_customers,
    ROUND(AVG(Tenure_in_Months), 1)                                               AS avg_tenure_months,
    ROUND(AVG(Monthly_Charge), 2)                                                 AS avg_monthly_charge,
    ROUND(AVG(Total_Revenue), 2)                                                  AS avg_lifetime_revenue,
    ROUND(AVG(Number_of_Referrals), 1)                                            AS avg_referrals
FROM telecom_customer_churn
GROUP BY Contract
ORDER BY avg_lifetime_revenue DESC;


/* ============================================================
   14  RETENTION RISK SCORING (ACTIVE CUSTOMERS)
   Purpose : Score currently active (Stayed) customers by how
             closely they resemble churned customers.
             Score ≥ 7  → High Risk
             Score 4–6  → Medium Risk
             Score < 4  → Low Risk
   ============================================================ */

-- Risk score for each active customer based on churn-correlated factors
SELECT
    Customer_ID,
    Tenure_in_Months,
    Monthly_Charge,
    Contract,
    Internet_Type,
    Premium_Tech_Support,
    Payment_Method,
    (
        CASE WHEN Contract          = 'Month-to-Month'    THEN 3 ELSE 0 END +
        CASE WHEN Monthly_Charge    > 80                  THEN 2 ELSE 0 END +
        CASE WHEN Tenure_in_Months  < 12                  THEN 2 ELSE 0 END +
        CASE WHEN Internet_Type     = 'Fiber Optic'       THEN 2 ELSE 0 END +
        CASE WHEN Premium_Tech_Support = 'No'             THEN 1 ELSE 0 END +
        CASE WHEN Payment_Method    = 'Electronic Check'  THEN 1 ELSE 0 END
    )                                                                             AS churn_risk_score,
    CASE
        WHEN (
            CASE WHEN Contract         = 'Month-to-Month'    THEN 3 ELSE 0 END +
            CASE WHEN Monthly_Charge   > 80                  THEN 2 ELSE 0 END +
            CASE WHEN Tenure_in_Months < 12                  THEN 2 ELSE 0 END +
            CASE WHEN Internet_Type    = 'Fiber Optic'       THEN 2 ELSE 0 END +
            CASE WHEN Premium_Tech_Support = 'No'            THEN 1 ELSE 0 END +
            CASE WHEN Payment_Method   = 'Electronic Check'  THEN 1 ELSE 0 END
        ) >= 7 THEN 'High Risk'
        WHEN (
            CASE WHEN Contract         = 'Month-to-Month'    THEN 3 ELSE 0 END +
            CASE WHEN Monthly_Charge   > 80                  THEN 2 ELSE 0 END +
            CASE WHEN Tenure_in_Months < 12                  THEN 2 ELSE 0 END +
            CASE WHEN Internet_Type    = 'Fiber Optic'       THEN 2 ELSE 0 END +
            CASE WHEN Premium_Tech_Support = 'No'            THEN 1 ELSE 0 END +
            CASE WHEN Payment_Method   = 'Electronic Check'  THEN 1 ELSE 0 END
        ) >= 4 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END                                                                           AS risk_level
FROM telecom_customer_churn
WHERE Customer_Status = 'Stayed'
ORDER BY churn_risk_score DESC;


-- Summarised risk level breakdown for active customers
SELECT
    CASE
        WHEN (num_conditions >= 3) THEN 'High Risk'
        WHEN num_conditions = 2    THEN 'Medium Risk'
        ELSE                            'Low Risk'
    END                                                                           AS risk_level,
    COUNT(Customer_ID)                                                            AS num_customers,
    ROUND(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER(), 1)        AS cust_pct,
    num_conditions
FROM (
    SELECT
        Customer_ID,
        SUM(CASE WHEN Offer                = 'Offer E' OR Offer = 'None' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN Contract             = 'Month-to-Month'            THEN 1 ELSE 0 END) +
        SUM(CASE WHEN Premium_Tech_Support = 'No'                        THEN 1 ELSE 0 END) +
        SUM(CASE WHEN Internet_Type        = 'Fiber Optic'               THEN 1 ELSE 0 END) AS num_conditions
    FROM telecom_customer_churn
    WHERE Monthly_Charge    > 70.05
      AND Customer_Status   = 'Stayed'
      AND Number_of_Referrals > 0
      AND Tenure_in_Months  > 9
    GROUP BY Customer_ID
    HAVING
        SUM(CASE WHEN Offer                = 'Offer E' OR Offer = 'None' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN Contract             = 'Month-to-Month'            THEN 1 ELSE 0 END) +
        SUM(CASE WHEN Premium_Tech_Support = 'No'                        THEN 1 ELSE 0 END) +
        SUM(CASE WHEN Internet_Type        = 'Fiber Optic'               THEN 1 ELSE 0 END) >= 1
) AS subquery
GROUP BY
    CASE
        WHEN (num_conditions >= 3) THEN 'High Risk'
        WHEN num_conditions = 2    THEN 'Medium Risk'
        ELSE                            'Low Risk'
    END,
    num_conditions;


/* ============================================================
   15  EXECUTIVE SUMMARY CTE                           ← NEW
   Purpose : Single query combining all key KPIs into one
             output row. Ideal for the Tableau KPI banner
             or for a PowerPoint summary slide.
             Uses CTEs to keep the logic readable.
   ============================================================ */

WITH
base AS (
    -- All customers and their revenue
    SELECT
        Customer_Status,
        Total_Revenue,
        Monthly_Charge,
        Churn_Category
    FROM telecom_customer_churn
),

totals AS (
    -- Aggregate KPIs across all customers
    SELECT
        COUNT(*)                                                                  AS total_customers,
        SUM(Total_Revenue)                                                        AS total_revenue,
        AVG(Monthly_Charge)                                                       AS avg_monthly_charge
    FROM base
),

churn_stats AS (
    -- Churn-specific aggregates
    SELECT
        COUNT(*)                                                                  AS total_churned,
        SUM(Total_Revenue)                                                        AS revenue_lost,
        AVG(Monthly_Charge)                                                       AS avg_charge_churned
    FROM base
    WHERE Customer_Status = 'Churned'
),

top_churn_reason AS (
    -- Most common reason customers churned
    SELECT TOP 1
        Churn_Category                                                            AS top_churn_category
    FROM base
    WHERE Customer_Status = 'Churned'
    GROUP BY Churn_Category
    ORDER BY COUNT(*) DESC
)

SELECT
    t.total_customers,
    c.total_churned,
    ROUND(c.total_churned * 100.0 / t.total_customers, 2)                        AS churn_rate_pct,
    CEILING(t.total_revenue)                                                      AS total_revenue_earned,
    CEILING(c.revenue_lost)                                                       AS total_revenue_lost,
    ROUND(c.revenue_lost * 100.0 / t.total_revenue, 1)                           AS revenue_loss_pct,
    ROUND(t.avg_monthly_charge, 2)                                                AS avg_monthly_charge_all,
    ROUND(c.avg_charge_churned, 2)                                                AS avg_monthly_charge_churners,
    r.top_churn_category                                                          AS primary_churn_driver
FROM totals   t
CROSS JOIN churn_stats    c
CROSS JOIN top_churn_reason r;

/* ============================================================
   END OF FILE
   ============================================================ */
