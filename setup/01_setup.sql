-- =====================================================================
-- SettleWatch | Step 1: Snowflake setup
-- Run this in a Snowsight worksheet. It creates the warehouse, database,
-- schemas, file format and stage that everything else uses.
-- =====================================================================

USE ROLE SYSADMIN;

-- One extra-small warehouse for all transformation work.
-- AUTO_SUSPEND = 60 turns it off after 60 seconds of no activity so it
-- stops using credits. AUTO_RESUME starts it again when a query arrives.
CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'SettleWatch: dbt runs and ad-hoc analysis';

-- A second warehouse for reporting, so dashboards never wait behind
-- dbt runs. Also used in the FinOps warehouse-sizing experiment.
CREATE WAREHOUSE IF NOT EXISTS REPORTING_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'SettleWatch: reports and dashboards';

USE WAREHOUSE TRANSFORM_WH;

CREATE DATABASE IF NOT EXISTS SETTLEWATCH
  COMMENT = 'Trade settlement analytics project';

-- RAW: data exactly as loaded from the CSV files
-- STAGING: cleaned, typed copies of RAW (built by dbt)
-- MARTS: the star schema and reports (built by dbt)
-- GOVERNANCE: masking and row access policies
CREATE SCHEMA IF NOT EXISTS SETTLEWATCH.RAW;
CREATE SCHEMA IF NOT EXISTS SETTLEWATCH.STAGING;
CREATE SCHEMA IF NOT EXISTS SETTLEWATCH.MARTS;
CREATE SCHEMA IF NOT EXISTS SETTLEWATCH.GOVERNANCE;

USE SCHEMA SETTLEWATCH.RAW;

-- Describes how to read our CSV files.
CREATE FILE FORMAT IF NOT EXISTS CSV_FORMAT
  TYPE = 'CSV'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('');

-- An internal stage is a folder inside Snowflake where you upload files
-- before loading them into tables.
CREATE STAGE IF NOT EXISTS RAW_STAGE
  FILE_FORMAT = CSV_FORMAT
  COMMENT = 'Upload trades.csv, stocks.csv and brokers.csv here';

SHOW WAREHOUSES LIKE '%_WH';
SHOW SCHEMAS IN DATABASE SETTLEWATCH;
