/*
  Helper macro to get all column information for models and sources in a single query.
  Returns a dictionary mapping table names to their column information.
*/

{%- macro _get_all_table_columns() -%}
  {%- if not graph or not graph.nodes -%}
    {{ return({}) }}
  {%- endif -%}

  {%- set table_info = [] -%}

  -- Add models to the list
  {%- for node_id, node in graph.nodes.items() -%}
    {%- if node.resource_type == 'model' and node.columns -%}
      {%- do table_info.append({
        'name': node.name,
        'schema': node.schema,
        'database': node.database,
        'type': 'model'
      }) -%}
    {%- endif -%}
  {%- endfor -%}

  -- Add sources to the list
  {%- for source_id, source in graph.sources.items() -%}
    {%- if source.columns -%}
      {%- do table_info.append({
        'name': source.name,
        'schema': source.schema,
        'database': source.database,
        'type': 'source'
      }) -%}
    {%- endif -%}
  {%- endfor -%}

  {%- if table_info | length == 0 -%}
    {{ return({}) }}
  {%- endif -%}

  -- Group tables by database to handle multiple databases
  {%- set databases = {} -%}
  {%- for table in table_info -%}
    {%- if table.database not in databases -%}
      {%- do databases.update({table.database: []}) -%}
    {%- endif -%}
    {%- do databases[table.database].append(table) -%}
  {%- endfor -%}

  {%- set all_columns_data = [] -%}

  -- Query each database separately, filtering only by schemas (much more efficient)
  {%- for database, tables in databases.items() -%}
    {%- set schema_names = [] -%}
    {%- for table in tables -%}
      {%- if table.schema not in schema_names -%}
        {%- do schema_names.append(table.schema) -%}
      {%- endif -%}
    {%- endfor -%}

    {%- set quoted_schema_names = [] -%}
    {%- for schema in schema_names -%}
      {%- do quoted_schema_names.append("'" ~ schema.upper() ~ "'") -%}
    {%- endfor -%}

    {%- set database_columns_query -%}
      select
        upper(table_catalog) as table_database,
        upper(table_schema) as table_schema,
        upper(table_name) as table_name,
        upper(column_name) as column_name,
        ordinal_position
      from {{ database }}.information_schema.columns
      where upper(table_schema) in ({{ quoted_schema_names | join(', ') }})
      order by table_catalog, table_schema, table_name, ordinal_position
    {%- endset -%}

    {%- set database_columns_result = run_query(database_columns_query) -%}
    {%- if database_columns_result.columns | length > 0 -%}
      {%- set databases_list = database_columns_result.columns[0].values() -%}
      {%- set schemas_list = database_columns_result.columns[1].values() -%}
      {%- set table_names_list = database_columns_result.columns[2].values() -%}
      {%- set column_names_list = database_columns_result.columns[3].values() -%}

      {%- for i in range(table_names_list | length) -%}
        {%- do all_columns_data.append({
          'database': databases_list[i],
          'schema': schemas_list[i],
          'table_name': table_names_list[i],
          'column_name': column_names_list[i]
        }) -%}
      {%- endfor -%}
    {%- endif -%}
  {%- endfor -%}

  -- Process all the collected column data
  {%- set table_columns = {} -%}
  {%- for row in all_columns_data -%}
    {%- set table_key = row.table_name -%}
    {%- if table_key not in table_columns -%}
      {%- do table_columns.update({table_key: {'columns': []}}) -%}
    {%- endif -%}
    {%- do table_columns[table_key]['columns'].append(row.column_name) -%}
  {%- endfor -%}

  {{ return(table_columns) }}
{%- endmacro -%}

/*
  Helper macro to validate a single table's schema against its documentation.
  Works for both models and sources.
  Returns a dictionary with validation results.
*/

{%- macro _validate_single_table_schema(node, table_columns_info, resource_type) -%}

  -- Get actual columns from the pre-fetched data
  {%- set table_key = node.name.upper() -%}
  {%- if table_key in table_columns_info -%}
    {%- set actual_columns = table_columns_info[table_key]['columns'] -%}
  {%- else -%}
    {%- set actual_columns = [] -%}
  {%- endif -%}

  -- If no columns were found, the table doesn't exist in the database
  {%- if actual_columns | length == 0 -%}
    {%- set result = {
      'table_name': node.name,
      'table_schema': node.schema,
      'table_database': node.database,
      'resource_type': resource_type,
      'validation_issues': ['TABLE_NOT_FOUND'],
      'documented_but_missing_columns': [],
      'undocumented_columns': []
    } -%}
    {{ return(result) }}
  {%- endif -%}

  -- Get documented columns
  {%- set documented_columns = [] -%}
  {%- for column_name, column_info in node.columns.items() -%}
    {%- do documented_columns.append(column_name.upper()) -%}
  {%- endfor -%}

  -- Find missing and undocumented columns
  {%- set documented_but_missing_columns = [] -%}
  {%- for col in documented_columns -%}
    {%- if col not in actual_columns -%}
      {%- do documented_but_missing_columns.append(col) -%}
    {%- endif -%}
  {%- endfor -%}

  {%- set undocumented_columns = [] -%}
  {%- for col in actual_columns -%}
    {%- if col not in documented_columns -%}
      {%- do undocumented_columns.append(col) -%}
    {%- endif -%}
  {%- endfor -%}

  -- Determine validation issues as a list
  {%- set validation_issues = [] -%}

  {%- if documented_but_missing_columns | length > 0 -%}
    {%- do validation_issues.append('DOCUMENTED_BUT_MISSING_COLUMNS') -%}
  {%- endif -%}

  {%- if undocumented_columns | length > 0 -%}
    {%- do validation_issues.append('UNDOCUMENTED_COLUMNS') -%}
  {%- endif -%}

  {%- set result = {
    'table_name': node.name,
    'table_schema': node.schema,
    'table_database': node.database,
    'resource_type': resource_type,
    'validation_issues': validation_issues,
    'documented_but_missing_columns': documented_but_missing_columns,
    'undocumented_columns': undocumented_columns
  } -%}

  {{ return(result) }}
{%- endmacro -%}

/*
  Macro to validate all model and source schemas in the project against their documentation.

  This macro creates a comprehensive report of schema validation issues
  across all models and sources in the project.

  Usage:
    dbt run-operation validate_all_schemas  # Show all results (successes and failures)
    dbt run-operation validate_all_schemas --args '{"errors_only": true}'  # Show only failures
    dbt run-operation validate_all_schemas --args '{"undocumented_columns_as_errors": false}'  # Treat undocumented columns as warnings

  Args:
    errors_only (bool): If true, only shows tables with validation errors. Default: false
    undocumented_columns_as_errors (bool): If true, treats undocumented columns as validation errors.
                                          If false, undocumented columns are reported but don't cause failure. Default: true

  Note: This macro uses the dbt graph and should only be used in run-operations,
  not in models or analyses. The macro will always raise an error if validation issues are found.
*/

{%- macro validate_all_schemas(errors_only=false, undocumented_columns_as_errors=true) -%}

  {%- if not graph or not graph.nodes -%}
    {{ exceptions.raise_compiler_error("Error: This macro requires access to the dbt graph. Use 'dbt run-operation validate_all_schemas' instead of calling it from a model or analysis.") }}
  {%- endif -%}

  -- Define error issues based on the flag once at the top
  {%- set error_issues = ['DOCUMENTED_BUT_MISSING_COLUMNS', 'TABLE_NOT_FOUND'] -%}
  {%- if undocumented_columns_as_errors -%}
    {%- do error_issues.append('UNDOCUMENTED_COLUMNS') -%}
  {%- endif -%}

  -- Get all table column information in a single query
  {%- set table_columns_info = _get_all_table_columns() -%}

  {%- set validation_results = [] -%}
  {%- set failed_tables_list = [] -%}

  -- Validate models
  {%- for node_id, node in graph.nodes.items() -%}
    {%- if node.resource_type == 'model' and node.columns -%}
      {%- set result = _validate_single_table_schema(node, table_columns_info, 'model') -%}
      {%- do validation_results.append(result) -%}
    {%- endif -%}
  {%- endfor -%}

  -- Validate sources
  {%- for source_id, source in graph.sources.items() -%}
    {%- if source.columns -%}
      {%- set result = _validate_single_table_schema(source, table_columns_info, 'source') -%}
      {%- do validation_results.append(result) -%}
    {%- endif -%}
  {%- endfor -%}

  -- Process all validation results
  {%- for result in validation_results -%}
    {%- set resource_type = result.resource_type -%}

    -- Check if this table has any error issues
    {%- set has_errors = false -%}
    {%- for issue in result.validation_issues -%}
      {%- if issue in error_issues -%}
        {%- if not has_errors -%}
          {%- do failed_tables_list.append(result.table_name) -%}
          {%- set has_errors = true -%}
        {%- endif -%}
      {%- endif -%}
    {%- endfor -%}

    -- Log the result based on errors_only flag
    {%- if result.validation_issues | length == 0 -%}
      {%- if not errors_only -%}
        {{ log('✅ ' ~ resource_type | title ~ ' ' ~ result.table_name ~ ': Schema matches documentation', info=True) }}
      {%- endif -%}
    {%- elif 'TABLE_NOT_FOUND' in result.validation_issues -%}
      {%- if resource_type == 'model' -%}
        {{ log('❌ Model ' ~ result.table_name ~ ': Model not found in database (may not be built yet)', info=True) }}
      {%- else -%}
        {{ log('❌ Source ' ~ result.table_name ~ ': Source not found in database', info=True) }}
      {%- endif -%}
    {%- elif result.validation_issues == ['UNDOCUMENTED_COLUMNS'] and not undocumented_columns_as_errors -%}
      {%- if not errors_only -%}
        {{ log('✅ ' ~ resource_type | title ~ ' ' ~ result.table_name ~ ': Schema matches documentation', info=True) }}
        {{ log('   ⚠️  Undocumented columns (not treated as errors): ' ~ result.undocumented_columns | join(', '), info=True) }}
      {%- endif -%}
    {%- else -%}
      {{ log('❌ ' ~ resource_type | title ~ ' ' ~ result.table_name ~ ':', info=True) }}
      {%- if 'DOCUMENTED_BUT_MISSING_COLUMNS' in result.validation_issues -%}
        {{ log('   • Documented but missing columns: ' ~ result.documented_but_missing_columns | join(', '), info=True) }}
      {%- endif -%}
      {%- if 'UNDOCUMENTED_COLUMNS' in result.validation_issues -%}
        {%- if undocumented_columns_as_errors -%}
          {{ log('   • Undocumented columns: ' ~ result.undocumented_columns | join(', '), info=True) }}
        {%- else -%}
          {{ log('   ⚠️  Undocumented columns (not treated as errors): ' ~ result.undocumented_columns | join(', '), info=True) }}
        {%- endif -%}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}

  {%- set total_tables = validation_results | length -%}
  {%- set models_count = validation_results | selectattr('resource_type', '==', 'model') | list | length -%}
  {%- set sources_count = validation_results | selectattr('resource_type', '==', 'source') | list | length -%}

  -- Calculate counts using the failed_tables_list built during the first loop
  {%- set failed_tables_count = failed_tables_list | length -%}
  {%- set matching_tables_count = total_tables - failed_tables_count -%}

  -- Show summary unless errors_only is true and there are no errors
  {%- if not errors_only or failed_tables_list | length > 0 -%}
    {{ log('', info=True) }}
    {{ log('📊 Schema Validation Summary:', info=True) }}
    {{ log('   Total tables validated: ' ~ total_tables ~ ' (' ~ models_count ~ ' models, ' ~ sources_count ~ ' sources)', info=True) }}
    {%- if not errors_only -%}
      {{ log('   Tables with matching schemas: ' ~ matching_tables_count, info=True) }}
      {{ log('   Tables with schema issues: ' ~ failed_tables_count, info=True) }}
    {%- else -%}
      {{ log('   Tables with schema issues: ' ~ failed_tables_count, info=True) }}
    {%- endif -%}
  {%- endif -%}

  -- Handle validation errors - always fail if errors are found
  {%- if failed_tables_list | length > 0 -%}
    {{ exceptions.raise_compiler_error('Schema validation failed! ' ~ failed_tables_list | length ~ ' tables have validation errors.') }}
  {%- elif errors_only -%}
    {{ log('✅ No schema validation errors found!', info=True) }}
  {%- endif -%}

  {{ return('') }}

{%- endmacro -%}
