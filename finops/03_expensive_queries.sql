-- =====================================================================
-- SettleWatch | Step 6c: find the queries worth fixing
-- Each query below answers one FinOps question.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TRANSFORM_WH;

-- 1) The 10 slowest queries in the last 7 days.
SELECT query_id,
       LEFT(REGEXP_REPLACE(query_text, '\\s+', ' '), 100) AS query_start,
       warehouse_name,
       warehouse_size,
       ROUND(total_elapsed_time / 1000, 1)                AS elapsed_seconds,
       partitions_scanned,
       partitions_total
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
ORDER BY total_elapsed_time DESC
LIMIT 10;

-- 2) Full table scans: queries that read (almost) every partition of a
--    big table. These are candidates for better filters or clustering.
SELECT query_id,
       LEFT(REGEXP_REPLACE(query_text, '\\s+', ' '), 100) AS query_start,
       partitions_scanned,
       partitions_total,
       ROUND(100 * partitions_scanned / partitions_total, 1) AS pct_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND partitions_total > 100
  AND partitions_scanned / partitions_total > 0.9
ORDER BY partitions_scanned DESC
LIMIT 20;

-- 3) Spilling: the warehouse ran out of memory and wrote to disk.
--    This is the signal that a BIGGER warehouse may actually be cheaper.
SELECT query_id,
       warehouse_size,
       ROUND(bytes_spilled_to_local_storage / POWER(1024, 3), 2)  AS gb_spilled_local,
       ROUND(bytes_spilled_to_remote_storage / POWER(1024, 3), 2) AS gb_spilled_remote,
       ROUND(total_elapsed_time / 1000, 1)                        AS elapsed_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC, bytes_spilled_to_local_storage DESC
LIMIT 20;

-- 4) Queuing: queries waited because the warehouse was busy.
--    The fix here is more clusters (scale out), not a bigger size.
SELECT warehouse_name,
       COUNT_IF(queued_overload_time > 0)              AS queued_queries,
       ROUND(SUM(queued_overload_time) / 1000, 1)      AS total_seconds_queued
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY 1
ORDER BY 3 DESC;

-- 5) Idle time: hours where a warehouse was running but did little work.
--    If this is high, lower auto_suspend.
SELECT warehouse_name,
       DATE_TRUNC(hour, start_time)                    AS usage_hour,
       ROUND(credits_used_compute, 3)                  AS credits_billed,
       ROUND(credits_attributed_compute_queries, 3)    AS credits_used_by_queries,
       ROUND(credits_used_compute - credits_attributed_compute_queries, 3) AS idle_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY idle_credits DESC
LIMIT 20;
