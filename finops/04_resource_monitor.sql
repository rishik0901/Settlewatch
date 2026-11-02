-- =====================================================================
-- SettleWatch | Step 6d: a spending limit with alerts
--
-- A resource monitor watches credit use. Ours:
--   - emails a notification at 75% of the monthly quota
--   - suspends the warehouses at 100% (running queries finish first)
--   - suspends immediately at 110% (kills running queries)
-- Only ACCOUNTADMIN can create resource monitors.
-- =====================================================================

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE RESOURCE MONITOR SETTLEWATCH_MONTHLY_LIMIT
  WITH CREDIT_QUOTA = 20
       FREQUENCY = MONTHLY
       START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75  PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND
    ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE TRANSFORM_WH SET RESOURCE_MONITOR = SETTLEWATCH_MONTHLY_LIMIT;
ALTER WAREHOUSE REPORTING_WH SET RESOURCE_MONITOR = SETTLEWATCH_MONTHLY_LIMIT;

-- Check it.
SHOW RESOURCE MONITORS LIKE 'SETTLEWATCH%';

-- To get the 75% email: in Snowsight, open your profile (bottom left) >
-- Settings > Notifications and turn on resource monitor notifications.
