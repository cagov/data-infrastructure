{% macro generate_schema_name(custom_schema_name, node) -%}

{#
        Definitions:
            - custom_schema_name: schema provided via dbt_project.yml or model config
            - target.name: name of the target (dev for local development, prod for production, etc.)
            - target.schema: schema provided by the target defined in profiles.yml

        Rather than write to a schema prefixed with target.schema, we instead just write
        to the actual schema name, and get safety by separating dev and prod databases.
        If we start to experience analytics engineers stepping on each others toes in
        dev, we may want to restore prefixes there (while maintaining a prefix-free
        lifestyle in prod).
    #}
{%- if custom_schema_name is none -%} {{ target.schema.lower() | trim }}

{%- elif target.name == 'prd' -%} {{ custom_schema_name.lower() | trim }}

{%- else -%} {{ target.schema.lower() | trim }}_{{ custom_schema_name | trim }}

{%- endif -%}

{%- endmacro %}
