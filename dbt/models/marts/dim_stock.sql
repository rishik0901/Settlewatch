-- One row per stock (security).
select
    symbol,
    company_name,
    sector,
    exchange
from {{ ref('stg_stocks') }}
