select
    upper(trim(broker_id)) as broker_id,
    trim(broker_name)      as broker_name,
    trim(region)           as region
from {{ source('raw', 'brokers') }}
