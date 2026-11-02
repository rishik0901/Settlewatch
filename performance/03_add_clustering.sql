-- =====================================================================
-- SettleWatch | Step 5c: fix the table with a clustering key
--
-- Most queries filter on trade_date, so we want rows for the same date
-- stored together. Then a query for September 2026 only reads the
-- few micro-partitions that hold September 2026.
--
-- We build a sorted copy so you can compare before and after side by
-- side, then add a clustering key so Snowflake keeps it sorted as new
-- data arrives (Automatic Clustering runs in the background and does
-- use some credits; that is the trade-off to mention in interviews).
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.MARTS;

CREATE OR REPLACE TABLE FCT_TRADES_BIG_CLUSTERED AS
SELECT *
FROM FCT_TRADES_BIG
ORDER BY trade_date, broker_id;

ALTER TABLE FCT_TRADES_BIG_CLUSTERED CLUSTER BY (trade_date, broker_id);

-- Compare clustering quality. Lower average_depth = better.
SELECT 'BEFORE' AS version,
       PARSE_JSON(SYSTEM$CLUSTERING_INFORMATION('FCT_TRADES_BIG', '(trade_date)')):average_depth::FLOAT AS average_depth
UNION ALL
SELECT 'AFTER',
       PARSE_JSON(SYSTEM$CLUSTERING_INFORMATION('FCT_TRADES_BIG_CLUSTERED', '(trade_date)')):average_depth::FLOAT;

-- Now go back to 02_benchmark_queries.sql, change the SET tbl line to
--   SET tbl = 'FCT_TRADES_BIG_CLUSTERED';
-- and run it again. Write both sets of numbers in TUNING_LOG.md.
