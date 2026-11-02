-- =====================================================================
-- SettleWatch | Step 7d: prove the security works
-- Run each block and compare what each role sees. Screenshot the
-- results for your README.
-- =====================================================================

USE WAREHOUSE REPORTING_WH;

-- As ANALYST: account numbers masked, only US-East rows, no RAW access.
USE ROLE ANALYST;
SELECT trade_id, broker_id, account_number, notional_usd
FROM SETTLEWATCH.MARTS.FCT_TRADES
LIMIT 5;

SELECT region, COUNT(*) AS report_rows
FROM SETTLEWATCH.MARTS.RPT_DAILY_FAILS
GROUP BY region;

-- This one should FAIL with "does not exist or not authorized".
SELECT COUNT(*) FROM SETTLEWATCH.RAW.TRADES;

-- As AUDITOR: full account numbers, every region.
USE ROLE AUDITOR;
SELECT trade_id, broker_id, account_number, notional_usd
FROM SETTLEWATCH.MARTS.FCT_TRADES
LIMIT 5;

SELECT region, COUNT(*) AS report_rows
FROM SETTLEWATCH.MARTS.RPT_DAILY_FAILS
GROUP BY region;

-- Audit trail: who read the account_number column, and when?
-- ACCESS_HISTORY needs Enterprise edition and can lag by up to 3 hours.
USE ROLE ACCOUNTADMIN;
SELECT ah.query_start_time,
       ah.user_name,
       qh.role_name,
       obj.value:"objectName"::STRING AS object_name,
       col.value:"columnName"::STRING AS column_name
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
  ON ah.query_id = qh.query_id,
     LATERAL FLATTEN(ah.base_objects_accessed) obj,
     LATERAL FLATTEN(obj.value:"columns") col
WHERE obj.value:"objectName"::STRING = 'SETTLEWATCH.MARTS.FCT_TRADES'
  AND col.value:"columnName"::STRING = 'ACCOUNT_NUMBER'
ORDER BY ah.query_start_time DESC
LIMIT 50;
