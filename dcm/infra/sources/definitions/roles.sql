{% set sfx = suffix() %}
-- Functional roles: personas that aggregate access from database roles and warehouse roles.

DEFINE ROLE LOADER_{{ sfx }}
  COMMENT = 'Permissions to load data to the {{ raw_name }}_{{ sfx }} database';

DEFINE ROLE TRANSFORMER_{{ sfx }}
  COMMENT = 'Permissions to read from {{ raw_name }}_{{ sfx }}, read/write/control {{ transform_name }}_{{ sfx }} and {{ analytics_name }}_{{ sfx }}';

DEFINE ROLE REPORTER_{{ sfx }}
  COMMENT = 'Permissions to read from {{ analytics_name }}_{{ sfx }}';

DEFINE ROLE READER_{{ sfx }}
  COMMENT = 'Permissions to read all databases for CI purposes';

DEFINE DATABASE ROLE {{ analytics_name }}_{{ sfx }}.STREAMLIT_ACCESS
  COMMENT = 'Role to grant Streamlit creation privileges in {{ analytics_name }}_{{ sfx }}';
