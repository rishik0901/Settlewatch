-- =====================================================================
-- SettleWatch | Step 2: load the CSV files into RAW tables
--
-- First upload the 3 CSV files from the data/ folder to the stage.
-- Pick ONE way:
--   A) Snowsight UI: Data > Databases > SETTLEWATCH > RAW > Stages >
--      RAW_STAGE > "+ Files" and drop in the 3 CSVs.
--   B) SnowSQL command line (from the project folder):
--        PUT file://data/*.csv @SETTLEWATCH.RAW.RAW_STAGE AUTO_COMPRESS=TRUE;
-- Then run this whole script.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.RAW;

-- Check the files are there.
LIST @RAW_STAGE;

-- Raw tables keep the CSV columns as they are. dbt cleans them later.
CREATE OR REPLACE TABLE STOCKS (
    SYMBOL        VARCHAR,
    COMPANY_NAME  VARCHAR,
    SECTOR        VARCHAR,
    EXCHANGE      VARCHAR
);

CREATE OR REPLACE TABLE BROKERS (
    BROKER_ID     VARCHAR,
    BROKER_NAME   VARCHAR,
    REGION        VARCHAR
);

CREATE OR REPLACE TABLE TRADES (
    TRADE_ID        VARCHAR,
    TRADE_TS        VARCHAR,
    TRADE_DATE      VARCHAR,
    SETTLE_DATE     VARCHAR,
    SYMBOL          VARCHAR,
    SIDE            VARCHAR,
    QUANTITY        VARCHAR,
    PRICE           VARCHAR,
    BROKER_ID       VARCHAR,
    ACCOUNT_NUMBER  VARCHAR,
    STATUS          VARCHAR,
    FAIL_REASON     VARCHAR,
    _LOADED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- PATTERN matches the file whether or not it was compressed (.csv.gz).
COPY INTO STOCKS  FROM @RAW_STAGE PATTERN = '.*stocks[.]csv.*';
COPY INTO BROKERS FROM @RAW_STAGE PATTERN = '.*brokers[.]csv.*';

COPY INTO TRADES (TRADE_ID, TRADE_TS, TRADE_DATE, SETTLE_DATE, SYMBOL, SIDE,
                  QUANTITY, PRICE, BROKER_ID, ACCOUNT_NUMBER, STATUS, FAIL_REASON)
  FROM @RAW_STAGE
  PATTERN = '.*trades[.]csv.*';

-- Quick checks: expect 20 stocks, 8 brokers, 100,000 trades.
SELECT 'STOCKS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM STOCKS
UNION ALL SELECT 'BROKERS', COUNT(*) FROM BROKERS
UNION ALL SELECT 'TRADES', COUNT(*) FROM TRADES;

SELECT STATUS, COUNT(*) AS TRADES
FROM TRADES
GROUP BY STATUS;
