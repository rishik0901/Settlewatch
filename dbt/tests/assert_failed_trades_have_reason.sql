-- A failed trade must say why it failed, and a settled trade must not.

select trade_id, status, fail_reason
from {{ ref('fct_trades') }}
where (status = 'FAILED'  and fail_reason is null)
   or (status = 'SETTLED' and fail_reason is not null)
