-- =====================================================================
-- SettleWatch | Step 6a: where are my credits going?
--
-- SNOWFLAKE.ACCOUNT_USAGE holds a year of history about your account.
-- It can lag by up to a few hours, so recent activity may not show yet.
-- Run as ACCOUNTADMIN (the trial user has it).
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TRANSFORM_WH;

-- Change this to your contract price. Trial accounts are usually shown
-- at around $2 to $4 per credit depending on edition and region.
SET usd_per_credit = 3;

-- Credits per warehouse per day, last 30 days.
SELECT DATE_TRUNC(day, start_time)              AS usage_day,
       warehouse_name,
       ROUND(SUM(credits_used), 3)              AS credits_used,
       ROUND(SUM(credits_used) * $usd_per_credit, 2) AS est_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- Total per warehouse, and its share of all spend.
SELECT warehouse_name,
       ROUND(SUM(credits_used), 3)                                 AS credits_used,
       ROUND(100 * RATIO_TO_REPORT(SUM(credits_used)) OVER (), 1)  AS pct_of_total
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 2 DESC;

-- Storage cost driver: how much data each database holds.
SELECT usage_date,
       database_name,
       ROUND(average_database_bytes / POWER(1024, 3), 3) AS database_gb,
       ROUND(average_failsafe_bytes / POWER(1024, 3), 3) AS failsafe_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
WHERE database_name = 'SETTLEWATCH'
ORDER BY usage_date DESC
LIMIT 14;

-- Are warehouses set up to save money? auto_suspend should be small
-- (60 seconds here). A NULL or 0 auto_suspend means it never sleeps.
SHOW WAREHOUSES;
SELECT "name", "size", "auto_suspend", "auto_resume", "state"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
