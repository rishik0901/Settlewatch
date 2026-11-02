-- One row per trade. This is the fact table of the star schema.
-- It links to dim_stock, dim_broker and dim_date.

{{
    config(
        post_hook=(
            ["alter table {{ this }} modify column account_number set masking policy SETTLEWATCH.GOVERNANCE.MASK_ACCOUNT_NUMBER"]
            if var('apply_masking') else []
        )
    )
}}

select
    trade_id,
    trade_ts,
    trade_date,
    settle_date,
    symbol,
    broker_id,
    account_number,
    side,
    quantity,
    price,
    quantity * price                          as notional_usd,
    status,
    fail_reason,
    status = 'FAILED'                         as is_failed,
    datediff(day, trade_date, settle_date)    as calendar_days_to_settle,
    hour(trade_ts) >= 15                      as is_late_day_trade
from {{ ref('stg_trades') }}
