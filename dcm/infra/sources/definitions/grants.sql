{% set sfx = suffix() %}
-- Role hierarchy: grant functional roles to SYSADMIN per best practices.

GRANT ROLE LOADER_{{ sfx }} TO ROLE SYSADMIN;
GRANT ROLE TRANSFORMER_{{ sfx }} TO ROLE SYSADMIN;
GRANT ROLE REPORTER_{{ sfx }} TO ROLE SYSADMIN;
GRANT ROLE READER_{{ sfx }} TO ROLE SYSADMIN;

-- LOADER: RW on RAW, LOADING warehouses
GRANT DATABASE ROLE {{ raw_name }}_{{ sfx }}.RW TO ROLE LOADER_{{ sfx }};

{% for size_suffix in ['XS'] %}
GRANT ROLE LOADING_{{ size_suffix }}_{{ sfx }}_WH_MOU TO ROLE LOADER_{{ sfx }};
{% endfor %}

-- TRANSFORMER: RW on TRANSFORM and ANALYTICS, R on RAW, TRANSFORMING warehouses
GRANT DATABASE ROLE {{ transform_name }}_{{ sfx }}.RW TO ROLE TRANSFORMER_{{ sfx }};
GRANT DATABASE ROLE {{ analytics_name }}_{{ sfx }}.RW TO ROLE TRANSFORMER_{{ sfx }};
GRANT DATABASE ROLE {{ raw_name }}_{{ sfx }}.R TO ROLE TRANSFORMER_{{ sfx }};

{% for size_suffix in ['XS'] %}
GRANT ROLE TRANSFORMING_{{ size_suffix }}_{{ sfx }}_WH_MOU TO ROLE TRANSFORMER_{{ sfx }};
{% endfor %}

-- REPORTER: R on ANALYTICS, REPORTING warehouses
GRANT DATABASE ROLE {{ analytics_name }}_{{ sfx }}.R TO ROLE REPORTER_{{ sfx }};

{% for size_suffix in ['XS'] %}
GRANT ROLE REPORTING_{{ size_suffix }}_{{ sfx }}_WH_MOU TO ROLE REPORTER_{{ sfx }};
{% endfor %}

-- READER: R on all databases, REPORTING warehouses
GRANT DATABASE ROLE {{ raw_name }}_{{ sfx }}.R TO ROLE READER_{{ sfx }};
GRANT DATABASE ROLE {{ transform_name }}_{{ sfx }}.R TO ROLE READER_{{ sfx }};
GRANT DATABASE ROLE {{ analytics_name }}_{{ sfx }}.R TO ROLE READER_{{ sfx }};

{% for size_suffix in ['XS'] %}
GRANT ROLE REPORTING_{{ size_suffix }}_{{ sfx }}_WH_MOU TO ROLE READER_{{ sfx }};
{% endfor %}

-- STREAMLIT: grant to REPORTER, with creation privileges on ANALYTICS schemas
GRANT DATABASE ROLE {{ analytics_name }}_{{ sfx }}.STREAMLIT_ACCESS TO ROLE REPORTER_{{ sfx }};

GRANT CREATE STREAMLIT, CREATE STAGE, CREATE NOTEBOOK
  ON FUTURE SCHEMAS IN DATABASE {{ analytics_name }}_{{ sfx }}
  TO DATABASE ROLE {{ analytics_name }}_{{ sfx }}.STREAMLIT_ACCESS;
