-- =====================================================================
-- SettleWatch | Step 5b: benchmark queries
--
-- Run each query, then run the "measure" query right after it and copy
-- the numbers into TUNING_LOG.md. Also click the query in
-- Monitoring > Query History and open its Query Profile.
--
-- Run this script twice:
--   1st time with  SET tbl = 'FCT_TRADES_BIG';            (before)
--   2nd time with  SET tbl = 'FCT_TRADES_BIG_CLUSTERED';  (after step 5c)
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.MARTS;

-- Turn off the result cache. Otherwise a repeated query returns
-- instantly from cache and the timing means nothing.
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SET tbl = 'FCT_TRADES_BIG';
ALTER SESSION SET QUERY_TAG = 'settlewatch_benchmark';

-- ---------------------------------------------------------------------
-- Q1: fail rate per broker for one month (a typical ops report)
-- ---------------------------------------------------------------------
SELECT broker_id,
       COUNT(*)                                     AS total_trades,
       COUNT_IF(is_failed)                          AS failed_trades,
       ROUND(100 * failed_trades / total_trades, 2) AS fail_rate_pct
FROM IDENTIFIER($tbl)
WHERE trade_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY broker_id
ORDER BY fail_rate_pct DESC;

-- Measure: partitions scanned vs total for the query you just ran.
SELECT operator_type,
       operator_statistics:pruning:partitions_scanned::INT AS partitions_scanned,
       operator_statistics:pruning:partitions_total::INT   AS partitions_total,
       ROUND(100 * partitions_scanned / NULLIF(partitions_total, 0), 1) AS pct_scanned
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
WHERE operator_type = 'TableScan';

-- ---------------------------------------------------------------------
-- Q2a: monthly value traded per stock in 2024, written the SLOW way.
-- Wrapping the filter column in a function (YEAR(trade_date)) can stop
-- Snowflake from skipping partitions. Check the Query Profile.
-- ---------------------------------------------------------------------
SELECT symbol,
       DATE_TRUNC(month, trade_date) AS trade_month,
       SUM(notional_usd)             AS total_notional_usd
FROM IDENTIFIER($tbl)
WHERE YEAR(trade_date) = 2024
GROUP BY 1, 2
ORDER BY 1, 2;

SELECT operator_type,
       operator_statistics:pruning:partitions_scanned::INT AS partitions_scanned,
       operator_statistics:pruning:partitions_total::INT   AS partitions_total
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
WHERE operator_type = 'TableScan';

-- ---------------------------------------------------------------------
-- Q2b: same result, written the FAST way: a plain date range.
-- ---------------------------------------------------------------------
SELECT symbol,
       DATE_TRUNC(month, trade_date) AS trade_month,
       SUM(notional_usd)             AS total_notional_usd
FROM IDENTIFIER($tbl)
WHERE trade_date >= '2024-01-01' AND trade_date < '2025-01-01'
GROUP BY 1, 2
ORDER BY 1, 2;

SELECT operator_type,
       operator_statistics:pruning:partitions_scanned::INT AS partitions_scanned,
       operator_statistics:pruning:partitions_total::INT   AS partitions_total
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
WHERE operator_type = 'TableScan';

-- ---------------------------------------------------------------------
-- Q3: look up a single trade by ID (what a support analyst does).
-- Clustering by date does NOT help this one. See 04_search_optimization.sql.
-- ---------------------------------------------------------------------
SELECT *
FROM IDENTIFIER($tbl)
WHERE trade_id = 'T0000054321-250';

SELECT operator_type,
       operator_statistics:pruning:partitions_scanned::INT AS partitions_scanned,
       operator_statistics:pruning:partitions_total::INT   AS partitions_total
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
WHERE operator_type = 'TableScan';

-- ---------------------------------------------------------------------
-- Q4a vs Q4b: SELECT * reads every column. Snowflake stores data by
-- column, so asking only for the columns you need reads far less data.
-- Compare "Bytes scanned" for these two in the Query Profile.
-- ---------------------------------------------------------------------
SELECT *
FROM IDENTIFIER($tbl)
WHERE trade_date = '2025-06-16'
  AND is_failed;

SELECT trade_id, broker_id, fail_reason, notional_usd
FROM IDENTIFIER($tbl)
WHERE trade_date = '2025-06-16'
  AND is_failed;

-- ---------------------------------------------------------------------
-- Summary of everything above: elapsed time and bytes scanned.
-- (INFORMATION_SCHEMA shows your recent queries straight away.)
-- ---------------------------------------------------------------------
SELECT query_id,
       LEFT(REGEXP_REPLACE(query_text, '\\s+', ' '), 80) AS query_start,
       warehouse_size,
       total_elapsed_time / 1000                        AS elapsed_seconds,
       ROUND(bytes_scanned / POWER(1024, 2), 1)         AS mb_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION(RESULT_LIMIT => 100))
WHERE query_tag = 'settlewatch_benchmark'
  AND query_type = 'SELECT'
  AND query_text NOT ILIKE '%GET_QUERY_OPERATOR_STATS%'
  AND query_text NOT ILIKE '%QUERY_HISTORY_BY_SESSION%'
ORDER BY start_time;

ALTER SESSION UNSET QUERY_TAG;
