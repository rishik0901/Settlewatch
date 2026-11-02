-- =====================================================================
-- SettleWatch | Step 7a: roles (RBAC)
--
-- Users get roles, roles get permissions. Three roles:
--   DATA_ENGINEER - builds everything (runs dbt)
--   ANALYST       - reads reports in MARTS; account numbers are masked
--   AUDITOR       - reads MARTS with full account numbers (compliance)
-- Least privilege: nobody gets more than their job needs.
-- =====================================================================

USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS DATA_ENGINEER COMMENT = 'Builds SettleWatch pipelines';
CREATE ROLE IF NOT EXISTS ANALYST       COMMENT = 'Reads SettleWatch reports, masked PII';
CREATE ROLE IF NOT EXISTS AUDITOR       COMMENT = 'Reads SettleWatch reports, full PII for compliance';

-- Best practice: custom roles roll up to SYSADMIN, so admins can manage
-- the objects they create.
GRANT ROLE DATA_ENGINEER TO ROLE SYSADMIN;
GRANT ROLE ANALYST       TO ROLE SYSADMIN;
GRANT ROLE AUDITOR       TO ROLE SYSADMIN;

-- Give yourself all three roles so you can test switching between them.
SET my_user = CURRENT_USER();
GRANT ROLE DATA_ENGINEER TO USER IDENTIFIER($my_user);
GRANT ROLE ANALYST       TO USER IDENTIFIER($my_user);
GRANT ROLE AUDITOR       TO USER IDENTIFIER($my_user);

-- ---------------------------------------------------------------------
-- What each role may use
-- ---------------------------------------------------------------------

-- Warehouses: engineers transform, readers only use the reporting one.
GRANT USAGE ON WAREHOUSE TRANSFORM_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE REPORTING_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE REPORTING_WH TO ROLE ANALYST;
GRANT USAGE ON WAREHOUSE REPORTING_WH TO ROLE AUDITOR;

GRANT USAGE ON DATABASE SETTLEWATCH TO ROLE DATA_ENGINEER;
GRANT USAGE ON DATABASE SETTLEWATCH TO ROLE ANALYST;
GRANT USAGE ON DATABASE SETTLEWATCH TO ROLE AUDITOR;

-- Engineers: full use of the pipeline schemas.
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA SETTLEWATCH.RAW     TO ROLE DATA_ENGINEER;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA SETTLEWATCH.STAGING TO ROLE DATA_ENGINEER;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA SETTLEWATCH.MARTS   TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA SETTLEWATCH.RAW    TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA SETTLEWATCH.RAW TO ROLE DATA_ENGINEER;

-- Analysts and auditors: read-only, MARTS only (no RAW, no STAGING).
GRANT USAGE ON SCHEMA SETTLEWATCH.MARTS TO ROLE ANALYST;
GRANT USAGE ON SCHEMA SETTLEWATCH.MARTS TO ROLE AUDITOR;
GRANT SELECT ON ALL TABLES IN SCHEMA SETTLEWATCH.MARTS TO ROLE ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA SETTLEWATCH.MARTS TO ROLE AUDITOR;

-- FUTURE grants: tables dbt creates later get the same access
-- automatically, so a dbt rebuild never breaks the analysts' access.
GRANT SELECT ON FUTURE TABLES IN SCHEMA SETTLEWATCH.MARTS TO ROLE ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA SETTLEWATCH.MARTS TO ROLE AUDITOR;

-- Review what each role can do.
SHOW GRANTS TO ROLE ANALYST;
SHOW GRANTS TO ROLE AUDITOR;
SHOW FUTURE GRANTS IN SCHEMA SETTLEWATCH.MARTS;
