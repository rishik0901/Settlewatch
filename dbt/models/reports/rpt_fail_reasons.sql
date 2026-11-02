-- Why trades fail, per broker and month. Helps operations decide where
-- to focus (for example: one broker with many late instructions).

select
    date_trunc(month, t.trade_date)       as trade_month,
    t.broker_id,
    b.broker_name,
    t.fail_reason,
    count(*)                              as failed_trades,
    sum(t.notional_usd)                   as failed_notional_usd
from {{ ref('fct_trades') }} t
join {{ ref('dim_broker') }} b
  on t.broker_id = b.broker_id
where t.is_failed
group by 1, 2, 3, 4
