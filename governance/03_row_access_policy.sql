-- =====================================================================
-- SettleWatch | Step 7c (optional): row-level security
--
-- A row access policy decides which ROWS each role can see. Here the
-- ANALYST role only sees brokers in the US-East region in the daily
-- fails report. The mapping table makes it easy to change later
-- without touching the policy.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.GOVERNANCE;

CREATE OR REPLACE TABLE REGION_ACCESS (
    role_name VARCHAR,
    region    VARCHAR
);

INSERT INTO REGION_ACCESS VALUES
    ('ANALYST', 'US-East');

CREATE OR REPLACE ROW ACCESS POLICY REGION_FILTER AS (row_region VARCHAR)
RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('AUDITOR', 'SYSADMIN', 'DATA_ENGINEER', 'ACCOUNTADMIN')
  OR EXISTS (
      SELECT 1
      FROM SETTLEWATCH.GOVERNANCE.REGION_ACCESS a
      WHERE a.role_name = CURRENT_ROLE()
        AND a.region = row_region
  )
  COMMENT = 'Analysts only see rows for regions listed in REGION_ACCESS';

ALTER TABLE SETTLEWATCH.MARTS.RPT_DAILY_FAILS
  ADD ROW ACCESS POLICY REGION_FILTER ON (region);

-- Like masking, dbt rebuilds remove it. Run dbt with
--   dbt build --vars '{apply_masking: true, apply_row_access: true}'
-- to have it re-applied automatically.
