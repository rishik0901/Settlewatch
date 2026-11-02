select trade_id, quantity, price, notional_usd
from {{ ref('fct_trades') }}
where notional_usd <= 0
