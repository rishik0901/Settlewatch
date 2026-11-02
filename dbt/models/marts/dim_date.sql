-- One row per calendar day, covering every trade and settlement date.
-- Built with Snowflake's GENERATOR function, which makes N empty rows.

with bounds as (

    select
        min(trade_date)  as start_date,
        max(settle_date) as end_date
    from {{ ref('stg_trades') }}

),

days as (

    -- row_number() gives 1, 2, 3 ... with no gaps (seq4() alone can skip numbers)
    select
        dateadd(day, row_number() over (order by seq4()) - 1, b.start_date) as date_day,
        b.end_date
    from bounds b,
         table(generator(rowcount => 3660))   -- up to 10 years

)

select
    date_day,
    year(date_day)                          as year,
    quarter(date_day)                       as quarter,
    month(date_day)                         as month,
    monthname(date_day)                     as month_name,
    dayofweekiso(date_day)                  as day_of_week,   -- 1 = Monday, 7 = Sunday
    dayname(date_day)                       as day_name,
    dayofweekiso(date_day) between 1 and 5  as is_business_day
from days
where date_day <= end_date
