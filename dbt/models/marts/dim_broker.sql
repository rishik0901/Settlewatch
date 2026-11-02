-- One row per broker (clearing member).
select
    broker_id,
    broker_name,
    region
from {{ ref('stg_brokers') }}
