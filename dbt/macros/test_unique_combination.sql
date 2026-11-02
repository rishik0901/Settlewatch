{#
  A small custom generic test: the combination of columns must be unique.
  (dbt_utils has one too; this avoids installing a package.)
#}
{% test unique_combination_of_columns(model, columns) %}
select {{ columns | join(', ') }}, count(*) as n
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
