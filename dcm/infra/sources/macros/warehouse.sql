{# Macro: warehouse with MOU access role.
   Creates a warehouse and an account role with MONITOR, OPERATE, USAGE. #}

{% macro warehouse(name, size, comment, auto_suspend=300) %}
{% set wh = name ~ '_' ~ suffix() %}

DEFINE WAREHOUSE {{ wh }}
  WAREHOUSE_SIZE = '{{ size }}'
  AUTO_SUSPEND = {{ auto_suspend }}
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = '{{ comment }}';

DEFINE ROLE {{ wh }}_WH_MOU
  COMMENT = 'Monitor, operate, and usage access to {{ wh }}';

GRANT MONITOR, OPERATE, USAGE ON WAREHOUSE {{ wh }}
  TO ROLE {{ wh }}_WH_MOU;

GRANT ROLE {{ wh }}_WH_MOU TO ROLE SYSADMIN;

{% endmacro %}
