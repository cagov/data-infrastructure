/*
  Post-hook macro to validate model schema after build.
  This runs automatically after each model is built and validates
  that the actual schema matches the documented schema.

  Uses transaction: false to avoid connection issues with Snowflake adapter.
  Only runs during execution phase when model.columns is available.
*/

{%- macro validate_model_schema_hook() -%}
  {% if execute %}
      -- Get the model node from the graph to access documented columns
      {%- set node = graph.nodes[model.unique_id] -%}
      {%- set documented_columns = node.columns -%}

      -- Get actual columns from the built model
      {%- set relation = api.Relation.create(database=model.database, schema=model.schema, identifier=model.name) -%}
      {%- set actual_columns = adapter.get_columns_in_relation(relation) -%}

      -- Compare documented vs actual columns (case-insensitive)
      {%- set documented_column_names = documented_columns.keys() | map('upper') | list -%}
      {%- set actual_column_names = actual_columns | map(attribute='name') | map('upper') | list -%}

      {%- set missing_from_docs = actual_column_names | reject('in', documented_column_names) | list -%}
      {%- set missing_from_model = documented_column_names | reject('in', actual_column_names) | list -%}

      {%- if missing_from_docs | length > 0 -%}
        {{ exceptions.warn("Columns in model but not documented: " ~ missing_from_docs) }}
      {%- endif -%}

      {%- if missing_from_model | length > 0 -%}
        {{ exceptions.warn("Columns documented but not in model: " ~ missing_from_model) }}
      {%- endif -%}

      -- Validate data types for documented columns
      {%- for column_name, column_info in documented_columns.items() -%}
        {%- if column_info.data_type -%}
          {%- set actual_column = actual_columns | selectattr('name', 'equalto', column_name.upper()) | first -%}
          {%- if actual_column -%}
            {%- set documented_type = column_info.data_type | upper -%}
            {%- set actual_type = actual_column.data_type | upper -%}

            {%- if documented_type != actual_type -%}
              {{ exceptions.warn("Data type mismatch for column '" ~ column_name ~ "': documented as " ~ documented_type ~ ", actual is " ~ actual_type) }}
            {%- endif -%}
          {%- endif -%}
        {%- endif -%}
      {%- endfor -%}

  {% endif %}

  -- Get actual columns from the built model

  select 1

{%- endmacro -%}
