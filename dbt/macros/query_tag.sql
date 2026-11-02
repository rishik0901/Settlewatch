{#
  Tags every query with the model name, for example
  settlewatch_dbt:fct_trades. finops/02_cost_per_dbt_model.sql groups
  credits by this tag.
#}
{% macro set_query_tag() -%}
    {% set new_query_tag = "settlewatch_dbt:" ~ model.name %}
    {% set original_query_tag = get_current_query_tag() %}
    {{ log("Setting query_tag to '" ~ new_query_tag ~ "'.") }}
    {% do run_query("alter session set query_tag = '{}'".format(new_query_tag)) %}
    {{ return(original_query_tag) }}
{%- endmacro %}
