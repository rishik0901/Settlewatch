-- =====================================================================
-- SettleWatch | Step 7b: hide account numbers (dynamic data masking)
--
-- A masking policy decides, at query time, what each role sees.
-- The data is stored once; only the displayed value changes.
--   AUDITOR, SYSADMIN, DATA_ENGINEER -> 736422102747
--   everyone else (ANALYST)          -> ********2747
--
-- Masking policies need Enterprise edition (the trial normally is).
-- Run after dbt has built MARTS.FCT_TRADES.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.GOVERNANCE;

CREATE OR REPLACE MASKING POLICY MASK_ACCOUNT_NUMBER AS (val STRING)
RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('AUDITOR', 'SYSADMIN', 'DATA_ENGINEER', 'ACCOUNTADMIN') THEN val
    WHEN val IS NULL THEN NULL
    ELSE REPEAT('*', GREATEST(LENGTH(val) - 4, 0)) || RIGHT(val, 4)
  END
  COMMENT = 'Shows only the last 4 digits of account numbers to non-privileged roles';

ALTER TABLE SETTLEWATCH.MARTS.FCT_TRADES
  MODIFY COLUMN account_number SET MASKING POLICY MASK_ACCOUNT_NUMBER;

-- dbt replaces FCT_TRADES on every run, which removes the policy. From
-- now on run dbt with:  dbt build --vars '{apply_masking: true}'
-- and fct_trades re-applies the policy itself (see its post_hook).

-- Where is the policy applied?
SELECT *
FROM TABLE(SETTLEWATCH.INFORMATION_SCHEMA.POLICY_REFERENCES(
    POLICY_NAME => 'SETTLEWATCH.GOVERNANCE.MASK_ACCOUNT_NUMBER'));
