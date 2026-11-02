# Tuning log

Fill this in as you run `02_benchmark_queries.sql` before and after
`03_add_clustering.sql`. These are the numbers your resume bullets come from,
so only write what you measured.

**Setup:** table `FCT_TRADES_BIG`, ______ rows, ______ GB, warehouse size XS,
result cache off.

**Clustering depth on trade_date:** before ______ → after ______

| # | Query | Before: seconds | Before: partitions scanned / total | Change made | After: seconds | After: partitions scanned / total | Improvement |
|---|---|---|---|---|---|---|---|
| Q1 | Fail rate per broker, one month | | | Clustering key on (trade_date, broker_id) | | | |
| Q2a | Value per stock per month, `YEAR(trade_date) = 2024` | | | (baseline) | | | |
| Q2b | Same, with a date range filter | | | Rewrote filter as a range | | | |
| Q3 | Look up one trade_id | | | Search optimization on trade_id | | | |
| Q4 | `SELECT *` vs 4 columns, one day of fails | MB scanned: | | Selected only needed columns | MB scanned: | | |

## What I learned

- Q1:
- Q2:
- Q3:
- Q4:

## Screenshots

Save Query Profile screenshots in `performance/screenshots/` and link them here.
