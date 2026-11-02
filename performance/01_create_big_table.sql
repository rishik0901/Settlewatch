-- =====================================================================
-- SettleWatch | Step 5a: make a big table (about 50 million rows)
--
-- Performance tuning only shows up on big tables. We copy fct_trades
-- 500 times with Snowflake's GENERATOR function and spread the copies
-- over 5 years (2022 to 2026).
--
-- ORDER BY RANDOM() shuffles the rows so they are stored in no useful
-- order. That is our "before" picture: a badly organised table.
--
-- Runs in a few minutes on an XS warehouse. Run it once.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.MARTS;

CREATE OR REPLACE TABLE FCT_TRADES_BIG AS
WITH copies AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS copy_no
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
)
SELECT
    t.trade_id || '-' || LPAD(c.copy_no::VARCHAR, 3, '0')     AS trade_id,
    DATEADD(year, -MOD(c.copy_no, 5), t.trade_ts)             AS trade_ts,
    DATEADD(year, -MOD(c.copy_no, 5), t.trade_date)           AS trade_date,
    DATEADD(year, -MOD(c.copy_no, 5), t.settle_date)          AS settle_date,
    t.symbol,
    t.broker_id,
    t.account_number,
    t.side,
    t.quantity,
    t.price,
    t.notional_usd,
    t.status,
    t.fail_reason,
    t.is_failed
FROM FCT_TRADES t
CROSS JOIN copies c
ORDER BY RANDOM();

-- How big is it?
SELECT COUNT(*) AS row_count FROM FCT_TRADES_BIG;

SELECT table_name, row_count, ROUND(bytes / POWER(1024, 3), 2) AS size_gb
FROM SETTLEWATCH.INFORMATION_SCHEMA.TABLES
WHERE table_name = 'FCT_TRADES_BIG';

-- How well is it clustered on trade_date? Look at average_depth:
-- a high number means each date is spread over many micro-partitions,
-- so a query for one date has to read lots of them.
SELECT SYSTEM$CLUSTERING_INFORMATION('FCT_TRADES_BIG', '(trade_date)');
