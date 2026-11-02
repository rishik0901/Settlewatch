-- =====================================================================
-- SettleWatch | Step 6b: cost per dbt model
--
-- Every dbt query is tagged "settlewatch_dbt:<model_name>" (see
-- dbt/macros/query_tag.sql). QUERY_ATTRIBUTION_HISTORY tells us how many
-- warehouse credits each query used, so we can add them up per model.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TRANSFORM_WH;

SELECT REPLACE(query_tag, 'settlewatch_dbt:', '')     AS dbt_model,
       COUNT(*)                                        AS queries,
       ROUND(SUM(credits_attributed_compute), 5)       AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
WHERE query_tag LIKE 'settlewatch_dbt:%'
  AND start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY credits DESC;

-- Same idea using run time instead of credits (works even when the
-- attribution view is still empty because of its delay).
SELECT REPLACE(query_tag, 'settlewatch_dbt:', '')     AS dbt_model,
       COUNT(*)                                        AS queries,
       ROUND(SUM(execution_time) / 1000, 1)            AS total_seconds,
       ROUND(100 * RATIO_TO_REPORT(SUM(execution_time)) OVER (), 1) AS pct_of_dbt_runtime
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag LIKE 'settlewatch_dbt:%'
  AND start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY total_seconds DESC;
