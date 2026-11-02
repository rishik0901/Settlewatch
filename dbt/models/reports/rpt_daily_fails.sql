-- Daily settlement fail rate per broker. The main operations report.

{{
    config(
        post_hook=(
            ["alter table {{ this }} add row access policy SETTLEWATCH.GOVERNANCE.REGION_FILTER on (region)"]
            if var('apply_row_access') else []
        )
    )
}}

select
    t.trade_date,
    t.broker_id,
    b.broker_name,
    b.region,
    count(*)                                              as total_trades,
    count_if(t.is_failed)                                 as failed_trades,
    round(100 * failed_trades / total_trades, 2)          as fail_rate_pct,
    sum(t.notional_usd)                                   as total_notional_usd,
    sum(iff(t.is_failed, t.notional_usd, 0))              as failed_notional_usd
from {{ ref('fct_trades') }} t
join {{ ref('dim_broker') }} b
  on t.broker_id = b.broker_id
group by 1, 2, 3, 4
