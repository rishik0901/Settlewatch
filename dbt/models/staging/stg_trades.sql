-- Clean, typed version of the raw trades. No business logic here,
-- just fixing data types and making values consistent.

with source as (

    select * from {{ source('raw', 'trades') }}

),

cleaned as (

    select
        trim(trade_id)                          as trade_id,
        to_timestamp_ntz(trade_ts)              as trade_ts,
        to_date(trade_date)                     as trade_date,
        to_date(settle_date)                    as settle_date,
        upper(trim(symbol))                     as symbol,
        upper(trim(side))                       as side,
        quantity::number(18, 0)                 as quantity,
        price::number(18, 2)                    as price,
        upper(trim(broker_id))                  as broker_id,
        trim(account_number)                    as account_number,
        upper(trim(status))                     as status,
        nullif(upper(trim(fail_reason)), '')    as fail_reason,
        _loaded_at
    from source

)

select * from cleaned
