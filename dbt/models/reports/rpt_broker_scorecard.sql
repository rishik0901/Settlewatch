-- One row per broker: overall fail rate and how it compares to the
-- average of all brokers. Brokers well above average are flagged.

with by_broker as (

    select
        broker_id,
        broker_name,
        region,
        sum(total_trades)   as total_trades,
        sum(failed_trades)  as failed_trades,
        sum(failed_notional_usd) as failed_notional_usd
    from {{ ref('rpt_daily_fails') }}
    group by 1, 2, 3

)

select
    *,
    round(100 * failed_trades / total_trades, 2)                as fail_rate_pct,
    round(100 * sum(failed_trades) over () / sum(total_trades) over (), 2)
                                                                as all_brokers_fail_rate_pct,
    fail_rate_pct > 1.5 * all_brokers_fail_rate_pct             as needs_review
from by_broker
order by fail_rate_pct desc
