{#
  By default dbt names schemas like STAGING_STAGING. This macro makes dbt
  use the schema name we set in dbt_project.yml exactly (STAGING, MARTS).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
