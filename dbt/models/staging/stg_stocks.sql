select
    upper(trim(symbol))   as symbol,
    trim(company_name)    as company_name,
    trim(sector)          as sector,
    upper(trim(exchange)) as exchange
from {{ source('raw', 'stocks') }}
