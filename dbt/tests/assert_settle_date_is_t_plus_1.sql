-- Every trade must settle on the next business day (T+1).
-- Friday trades settle on Monday. Holidays are ignored in this project.
-- The test fails if this query returns any rows.

select
    trade_id,
    trade_date,
    settle_date
from {{ ref('fct_trades') }}
where settle_date <> case
        when dayofweekiso(trade_date) = 5 then dateadd(day, 3, trade_date)  -- Friday
        when dayofweekiso(trade_date) = 6 then dateadd(day, 2, trade_date)  -- Saturday
        else dateadd(day, 1, trade_date)
    end
