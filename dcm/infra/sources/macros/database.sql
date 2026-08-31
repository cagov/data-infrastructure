{# Macro: database with database roles and grants.
   Creates a database and its R/RW database roles, wired up with inherited grants.

   Objects are owned by the functional role that creates them (e.g. TRANSFORMER),
   not by a database role. This avoids GRANT OWNERSHIP ON FUTURE entirely, and lets
   cross-database views resolve, since an account role can hold grants in more than
   one database. The tradeoff is that ownership is singular: if two functional roles
   ever need to replace the same objects, that requires a one-time ownership
   migration. #}

{% macro database(name, comment, retention_days=7) %}
{% set db = name ~ '_' ~ suffix() %}

DEFINE DATABASE {{ db }}
  DATA_RETENTION_TIME_IN_DAYS = {{ retention_days }}
  COMMENT = '{{ comment }}';

-- Database roles (access roles scoped to this database)
DEFINE DATABASE ROLE {{ db }}.R
  COMMENT = 'Read access to {{ db }}';

DEFINE DATABASE ROLE {{ db }}.RW
  COMMENT = 'Read/write access to {{ db }}, including creating objects';

-- Database role hierarchy: R → RW
GRANT DATABASE ROLE {{ db }}.R TO DATABASE ROLE {{ db }}.RW;

-- Database USAGE to R (inherited by RW via hierarchy)
GRANT USAGE ON DATABASE {{ db }} TO DATABASE ROLE {{ db }}.R;

-- R: schema USAGE, and SELECT on tables and views
GRANT INHERITED USAGE ON ALL SCHEMAS IN DATABASE {{ db }}
  TO DATABASE ROLE {{ db }}.R;

GRANT INHERITED SELECT, REFERENCES ON ALL TABLES IN DATABASE {{ db }}
  TO DATABASE ROLE {{ db }}.R;

GRANT INHERITED SELECT, REFERENCES ON ALL VIEWS IN DATABASE {{ db }}
  TO DATABASE ROLE {{ db }}.R;

-- RW: DML on tables
GRANT INHERITED INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN DATABASE {{ db }}
  TO DATABASE ROLE {{ db }}.RW;

-- RW: create objects within schemas
GRANT INHERITED CREATE FILE FORMAT, CREATE MATERIALIZED VIEW, CREATE PIPE,
  CREATE PROCEDURE, CREATE FUNCTION, CREATE STAGE, CREATE TABLE,
  CREATE TEMPORARY TABLE, CREATE VIEW, MODIFY, MONITOR, USAGE
  ON ALL SCHEMAS IN DATABASE {{ db }}
  TO DATABASE ROLE {{ db }}.RW;

-- RW: create schemas (supports per-developer dev schemas in dbt workflows)
GRANT CREATE SCHEMA ON DATABASE {{ db }}
  TO DATABASE ROLE {{ db }}.RW;

{% endmacro %}
