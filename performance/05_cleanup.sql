-- =====================================================================
-- SettleWatch | Clean up the big benchmark tables when you're done,
-- so they stop using storage and background clustering credits.
-- Your numbers are safe in TUNING_LOG.md.
-- =====================================================================

USE ROLE SYSADMIN;
USE SCHEMA SETTLEWATCH.MARTS;

ALTER TABLE IF EXISTS FCT_TRADES_BIG_CLUSTERED SUSPEND RECLUSTER;
DROP TABLE IF EXISTS FCT_TRADES_BIG_CLUSTERED;
DROP TABLE IF EXISTS FCT_TRADES_BIG;

-- Changed your mind within 1 day? Time Travel can bring a dropped table back:
-- UNDROP TABLE FCT_TRADES_BIG;
