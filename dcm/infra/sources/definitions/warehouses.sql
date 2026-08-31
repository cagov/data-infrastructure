{% set sizes = {
  'XS': 'X-SMALL',
} %}

{% for size_suffix, size in sizes.items() %}

{{ warehouse(
  name='LOADING_' ~ size_suffix,
  size=size,
  comment='Primary warehouse for loading data to Snowflake from ELT/ETL tools'
) }}

{{ warehouse(
  name='TRANSFORMING_' ~ size_suffix,
  size=size,
  comment='Primary warehouse for transforming data'
) }}

{{ warehouse(
  name='REPORTING_' ~ size_suffix,
  size=size,
  comment='Primary warehouse for reporting'
) }}

{% endfor %}
