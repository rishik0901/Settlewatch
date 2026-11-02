-- =====================================================================
-- SettleWatch | Optional: Snowpark (Python inside Snowflake)
--
-- A stored procedure written in Python that finds unusual days: days
-- where a broker's fail rate is far above its own recent average.
--
-- How it works (z-score):
--   For each broker and day, compare the fail rate with the average and
--   standard deviation of the previous 20 trading days.
--   z = (today - average) / std_dev. A z above 2.5 is flagged.
--
-- The Python runs on the Snowflake warehouse, so data never leaves
-- Snowflake. Run after dbt has built MARTS.RPT_DAILY_FAILS.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SETTLEWATCH.MARTS;

CREATE OR REPLACE PROCEDURE FLAG_FAIL_ANOMALIES(Z_THRESHOLD FLOAT)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
AS
$$
from snowflake.snowpark import Session, Window
from snowflake.snowpark import functions as F


def run(session: Session, z_threshold: float) -> str:
    daily = session.table("SETTLEWATCH.MARTS.RPT_DAILY_FAILS").select(
        "TRADE_DATE", "BROKER_ID", "BROKER_NAME", "TOTAL_TRADES", "FAILED_TRADES", "FAIL_RATE_PCT"
    )

    # The 20 trading days BEFORE each day (today is not included).
    prior_20 = (
        Window.partition_by("BROKER_ID")
        .order_by("TRADE_DATE")
        .rows_between(-20, -1)
    )

    scored = (
        daily.with_column("AVG_FAIL_RATE_20D", F.avg("FAIL_RATE_PCT").over(prior_20))
        .with_column("STD_FAIL_RATE_20D", F.stddev("FAIL_RATE_PCT").over(prior_20))
        .with_column(
            "Z_SCORE",
            # Only score days where the broker's fail rate actually varied.
            F.when(
                F.col("STD_FAIL_RATE_20D") > 0,
                (F.col("FAIL_RATE_PCT") - F.col("AVG_FAIL_RATE_20D")) / F.col("STD_FAIL_RATE_20D"),
            ),
        )
    )

    anomalies = (
        scored.filter(F.col("Z_SCORE") > F.lit(z_threshold))
        .with_column("Z_SCORE", F.round("Z_SCORE", 2))
        .with_column("AVG_FAIL_RATE_20D", F.round("AVG_FAIL_RATE_20D", 2))
        .with_column("FLAGGED_AT", F.current_timestamp())
        .drop("STD_FAIL_RATE_20D")
    )

    anomalies.write.mode("overwrite").save_as_table("SETTLEWATCH.MARTS.FAIL_ANOMALIES")
    count = session.table("SETTLEWATCH.MARTS.FAIL_ANOMALIES").count()
    return f"Flagged {count} broker-days with z-score above {z_threshold}"
$$;

CALL FLAG_FAIL_ANOMALIES(2.5);

SELECT *
FROM FAIL_ANOMALIES
ORDER BY z_score DESC
LIMIT 20;

-- Optional: run it every weekday at 7am New York time with a Task.
-- CREATE OR REPLACE TASK DAILY_FAIL_ANOMALIES
--   WAREHOUSE = TRANSFORM_WH
--   SCHEDULE = 'USING CRON 0 7 * * 1-5 America/New_York'
-- AS
--   CALL FLAG_FAIL_ANOMALIES(2.5);
-- ALTER TASK DAILY_FAIL_ANOMALIES RESUME;   -- tasks start suspended
-- ALTER TASK DAILY_FAIL_ANOMALIES SUSPEND;  -- stop it when done
