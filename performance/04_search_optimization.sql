-- =====================================================================
-- SettleWatch | Step 5d (optional): speed up single-trade lookups
--
-- Clustering helps range filters (dates). For "find this one trade_id"
-- Snowflake offers the Search Optimization Service, which builds a
-- lookup structure for equality filters.
--
-- Needs Enterprise edition (the free trial normally is Enterprise) and
-- uses credits to build and maintain, so try it once, measure, and drop it.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.MARTS;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

ALTER TABLE FCT_TRADES_BIG_CLUSTERED ADD SEARCH OPTIMIZATION ON EQUALITY(trade_id);

-- Wait until search_optimization_progress shows 100 (a few minutes).
SHOW TABLES LIKE 'FCT_TRADES_BIG_CLUSTERED';
SELECT "name", "search_optimization", "search_optimization_progress"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Re-run the lookup and compare with Q3 in your tuning log.
SELECT *
FROM FCT_TRADES_BIG_CLUSTERED
WHERE trade_id = 'T0000054321-250';

SELECT operator_type,
       operator_statistics:pruning:partitions_scanned::INT AS partitions_scanned,
       operator_statistics:pruning:partitions_total::INT   AS partitions_total
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
WHERE operator_type = 'TableScan';

-- When you've written down the result, remove it to stop the cost:
-- ALTER TABLE FCT_TRADES_BIG_CLUSTERED DROP SEARCH OPTIMIZATION;
