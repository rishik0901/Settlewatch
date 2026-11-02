-- =====================================================================
-- SettleWatch | Step 6e: is a bigger warehouse worth it?
--
-- Each size up doubles the credits per hour (XS = 1, S = 2, M = 4)
-- and gives twice the compute. If a query runs twice as fast on S, it
-- costs the same. If it runs less than twice as fast, XS is cheaper.
-- Note: Snowflake bills at least 60 seconds each time a warehouse starts.
-- =====================================================================

USE ROLE SYSADMIN;
USE SCHEMA SETTLEWATCH.MARTS;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
ALTER SESSION SET QUERY_TAG = 'settlewatch_sizing';

-- The test workload: a heavy aggregation over the whole big table.
-- Run it once per size.

-- Size XS
ALTER WAREHOUSE REPORTING_WH SET WAREHOUSE_SIZE = 'XSMALL';
USE WAREHOUSE REPORTING_WH;
SELECT symbol, broker_id, YEAR(trade_date) AS yr,
       COUNT(*) AS trades, SUM(notional_usd) AS notional, COUNT_IF(is_failed) AS fails
FROM FCT_TRADES_BIG
GROUP BY 1, 2, 3
ORDER BY notional DESC;

-- Size S
ALTER WAREHOUSE REPORTING_WH SET WAREHOUSE_SIZE = 'SMALL';
SELECT symbol, broker_id, YEAR(trade_date) AS yr,
       COUNT(*) AS trades, SUM(notional_usd) AS notional, COUNT_IF(is_failed) AS fails
FROM FCT_TRADES_BIG
GROUP BY 1, 2, 3
ORDER BY notional DESC;

-- Size M
ALTER WAREHOUSE REPORTING_WH SET WAREHOUSE_SIZE = 'MEDIUM';
SELECT symbol, broker_id, YEAR(trade_date) AS yr,
       COUNT(*) AS trades, SUM(notional_usd) AS notional, COUNT_IF(is_failed) AS fails
FROM FCT_TRADES_BIG
GROUP BY 1, 2, 3
ORDER BY notional DESC;

-- Always put it back to XS!
ALTER WAREHOUSE REPORTING_WH SET WAREHOUSE_SIZE = 'XSMALL';

-- Compare: runtime and estimated credits for each size.
SELECT warehouse_size,
       ROUND(total_elapsed_time / 1000, 1) AS elapsed_seconds,
       CASE warehouse_size
            WHEN 'X-Small' THEN 1 WHEN 'Small' THEN 2 WHEN 'Medium' THEN 4
            WHEN 'Large' THEN 8 END        AS credits_per_hour,
       ROUND(credits_per_hour * execution_time / 1000 / 3600, 5) AS est_credits
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION(RESULT_LIMIT => 50))
WHERE query_tag = 'settlewatch_sizing'
  AND query_type = 'SELECT'
  AND query_text ILIKE '%FROM FCT_TRADES_BIG%'
  AND query_text NOT ILIKE '%QUERY_HISTORY_BY_SESSION%'
ORDER BY start_time;

ALTER SESSION UNSET QUERY_TAG;
