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

  -- Query each database separately
  {%- for database, tables in databases.items() -%}
    {%- set table_conditions = [] -%}
    {%- for table in tables -%}
      {%- do table_conditions.append("(upper(table_name) = upper('" ~ table.name ~ "') and upper(table_schema) = upper('" ~ table.schema ~ "'))") -%}
    {%- endfor -%}

    {%- set database_columns_query -%}
      select
        upper(table_catalog) as table_database,
        upper(table_schema) as table_schema,
        upper(table_name) as table_name,
        upper(column_name) as column_name,
        upper(data_type) as data_type,
        ordinal_position
      from {{ database }}.information_schema.columns
      where ({{ table_conditions | join(' or ') }})
      order by table_catalog, table_schema, table_name, ordinal_position
    {%- endset -%}

    {%- set database_columns_result = run_query(database_columns_query) -%}
    {%- if database_columns_result.columns | length > 0 -%}
      {%- set databases_list = database_columns_result.columns[0].values() -%}
      {%- set schemas_list = database_columns_result.columns[1].values() -%}
      {%- set table_names_list = database_columns_result.columns[2].values() -%}
      {%- set column_names_list = database_columns_result.columns[3].values() -%}
      {%- set data_types_list = database_columns_result.columns[4].values() -%}

      {%- for i in range(table_names_list | length) -%}
        {%- do all_columns_data.append({
          'database': databases_list[i],
          'schema': schemas_list[i],
          'table_name': table_names_list[i],
          'column_name': column_names_list[i],
          'data_type': data_types_list[i]
        }) -%}
      {%- endfor -%}
    {%- endif -%}
  {%- endfor -%}

  -- Process all the collected column data
  {%- set table_columns = {} -%}
  {%- for row in all_columns_data -%}
    {%- set table_key = row.table_name -%}
    {%- if table_key not in table_columns -%}
      {%- do table_columns.update({table_key: {'columns': [], 'data_types': {}}}) -%}
    {%- endif -%}
    {%- do table_columns[table_key]['columns'].append(row.column_name) -%}
    {%- do table_columns[table_key]['data_types'].update({row.column_name: row.data_type}) -%}
  {%- endfor -%}

  {{ return(table_columns) }}
{%- endmacro -%}

/*
  Helper macro to validate a single table's schema against its documentation.
  Works for both models and sources.
  Returns a dictionary with validation results.
*/

{%- macro _validate_single_table_schema(node, table_columns_info, resource_type) -%}
  {%- set table_name = node.name -%}
  {%- set table_schema = node.schema -%}
  {%- set table_database = node.database -%}

  -- Get actual columns from the pre-fetched data
  {%- set table_key = table_name.upper() -%}
  {%- if table_key in table_columns_info -%}
    {%- set actual_columns = table_columns_info[table_key]['columns'] -%}
    {%- set actual_data_types = table_columns_info[table_key]['data_types'] -%}
  {%- else -%}
    {%- set actual_columns = [] -%}
    {%- set actual_data_types = {} -%}
  {%- endif -%}

  -- If no columns were found, the table doesn't exist in the database
  {%- if actual_columns | length == 0 -%}
    {%- set result = {
      'table_name': table_name,
      'table_schema': table_schema,
      'table_database': table_database,
      'resource_type': resource_type,
      'validation_status': 'TABLE_NOT_FOUND',
      'validation_message': resource_type | title ~ ' not found in database',
      'actual_column_count': 0,
      'documented_column_count': 0,
      'documented_but_missing_columns': [],
      'undocumented_columns': [],
      'data_type_mismatches': []
    } -%}
    {{ return(result) }}
  {%- endif -%}

  -- Get documented columns and data types
  {%- set documented_columns = [] -%}
  {%- set documented_data_types = {} -%}
  {%- for column_name, column_info in node.columns.items() -%}
    {%- do documented_columns.append(column_name.upper()) -%}
    {%- if column_info.data_type -%}
      {%- do documented_data_types.update({column_name.upper(): column_info.data_type.upper()}) -%}
    {%- endif -%}
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

  -- Check data type mismatches (if data types are documented)
  {%- set data_type_mismatches = [] -%}
  {%- if documented_data_types | length > 0 -%}
    {%- for col_name in actual_columns -%}
      {%- if col_name in documented_data_types -%}
        {%- set actual_type = actual_data_types[col_name] -%}
        {%- set expected_type = documented_data_types[col_name] -%}
        {%- if actual_type != expected_type -%}
          {%- do data_type_mismatches.append(col_name ~ ' (expected: ' ~ expected_type ~ ', actual: ' ~ actual_type ~ ')') -%}
        {%- endif -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endif -%}

  -- Determine validation status and messages
  {%- set validation_status = 'SCHEMA_MATCH' -%}
  {%- set validation_messages = [] -%}

  {%- if documented_but_missing_columns | length > 0 -%}
    {%- set validation_status = 'DOCUMENTED_BUT_MISSING_COLUMNS' -%}
    {%- do validation_messages.append('Documented but missing columns: ' ~ documented_but_missing_columns | join(', ')) -%}
  {%- endif -%}

  {%- if undocumented_columns | length > 0 -%}
    {%- if validation_status == 'SCHEMA_MATCH' -%}
      {%- set validation_status = 'UNDOCUMENTED_COLUMNS' -%}
    {%- else -%}
      {%- set validation_status = 'MULTIPLE_ISSUES' -%}
    {%- endif -%}
    {%- do validation_messages.append('Undocumented columns: ' ~ undocumented_columns | join(', ')) -%}
  {%- endif -%}

  {%- if data_type_mismatches | length > 0 -%}
    {%- if validation_status == 'SCHEMA_MATCH' -%}
      {%- set validation_status = 'DATA_TYPE_MISMATCH' -%}
    {%- else -%}
      {%- set validation_status = 'MULTIPLE_ISSUES' -%}
    {%- endif -%}
    {%- do validation_messages.append('Data type mismatches: ' ~ data_type_mismatches | join(', ')) -%}
  {%- endif -%}

  {%- if validation_messages | length == 0 -%}
    {%- set validation_message = 'Schema matches documentation' -%}
  {%- else -%}
    {%- set validation_message = validation_messages | join('; ') -%}
  {%- endif -%}

  {%- set result = {
    'table_name': table_name,
    'table_schema': table_schema,
    'table_database': table_database,
    'resource_type': resource_type,
    'validation_status': validation_status,
    'validation_message': validation_message,
    'actual_column_count': actual_columns | length,
    'documented_column_count': documented_columns | length,
    'documented_but_missing_columns': documented_but_missing_columns,
    'undocumented_columns': undocumented_columns,
    'data_type_mismatches': data_type_mismatches
  } -%}

  {{ return(result) }}
{%- endmacro -%}

/*
  Macro to validate all model and source schemas in the project against their documentation.

  This macro creates a comprehensive report of schema validation issues
  across all models and sources in the project.

  Usage:
    dbt run-operation validate_all_schemas

  Note: This macro uses the dbt graph and should only be used in run-operations,
  not in models or analyses.
*/

{%- macro validate_all_schemas() -%}

  {%- if not graph or not graph.nodes -%}
    {{ log("Error: This macro requires access to the dbt graph. Use 'dbt run-operation validate_all_schemas' instead of calling it from a model or analysis.", info=True) }}
    {{ return("select 'ERROR: This macro requires access to the dbt graph' as error_message") }}
  {%- endif -%}

  -- Get all table column information in a single query
  {%- set table_columns_info = _get_all_table_columns() -%}

  {%- set validation_results = [] -%}

  -- Validate models
  {%- for node_id, node in graph.nodes.items() -%}
    {%- if node.resource_type == 'model' and node.columns -%}
      {%- set result = _validate_single_table_schema(node, table_columns_info, 'model') -%}
      {%- do validation_results.append(result) -%}

      -- Log the result
      {%- if result.validation_status == 'SCHEMA_MATCH' -%}
        {{ log('✅ Model ' ~ result.table_name ~ ': Schema matches documentation (' ~ result.actual_column_count ~ ' columns)', info=True) }}
      {%- elif result.validation_status == 'TABLE_NOT_FOUND' -%}
        {{ log('⚠️  Model ' ~ result.table_name ~ ': Model not found in database (may not be built yet)', info=True) }}
      {%- else -%}
        {{ log('❌ Model ' ~ result.table_name ~ ':', info=True) }}
        {%- if result.documented_but_missing_columns | length > 0 -%}
          {{ log('   • Documented but missing columns: ' ~ result.documented_but_missing_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.undocumented_columns | length > 0 -%}
          {{ log('   • Undocumented columns: ' ~ result.undocumented_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.data_type_mismatches | length > 0 -%}
          {{ log('   • Data type mismatches:', info=True) }}
          {%- for mismatch in result.data_type_mismatches -%}
            {{ log('     - ' ~ mismatch, info=True) }}
          {%- endfor -%}
        {%- endif -%}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}

  -- Validate sources
  {%- for source_id, source in graph.sources.items() -%}
    {%- if source.columns -%}
      {%- set result = _validate_single_table_schema(source, table_columns_info, 'source') -%}
      {%- do validation_results.append(result) -%}

      -- Log the result
      {%- if result.validation_status == 'SCHEMA_MATCH' -%}
        {{ log('✅ Source ' ~ result.table_name ~ ': Schema matches documentation (' ~ result.actual_column_count ~ ' columns)', info=True) }}
      {%- elif result.validation_status == 'TABLE_NOT_FOUND' -%}
        {{ log('⚠️  Source ' ~ result.table_name ~ ': Source not found in database', info=True) }}
      {%- else -%}
        {{ log('❌ Source ' ~ result.table_name ~ ':', info=True) }}
        {%- if result.documented_but_missing_columns | length > 0 -%}
          {{ log('   • Documented but missing columns: ' ~ result.documented_but_missing_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.undocumented_columns | length > 0 -%}
          {{ log('   • Undocumented columns: ' ~ result.undocumented_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.data_type_mismatches | length > 0 -%}
          {{ log('   • Data type mismatches:', info=True) }}
          {%- for mismatch in result.data_type_mismatches -%}
            {{ log('     - ' ~ mismatch, info=True) }}
          {%- endfor -%}
        {%- endif -%}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}

  {%- set total_tables = validation_results | length -%}
  {%- set models_count = validation_results | selectattr('resource_type', '==', 'model') | list | length -%}
  {%- set sources_count = validation_results | selectattr('resource_type', '==', 'source') | list | length -%}
  {%- set failed_tables = validation_results | selectattr('validation_status', 'in', ['DOCUMENTED_BUT_MISSING_COLUMNS', 'UNDOCUMENTED_COLUMNS', 'DATA_TYPE_MISMATCH', 'MULTIPLE_ISSUES']) | list | length -%}
  {%- set tables_not_found = validation_results | selectattr('validation_status', '==', 'TABLE_NOT_FOUND') | list | length -%}
  {%- set matching_tables = validation_results | selectattr('validation_status', '==', 'SCHEMA_MATCH') | list | length -%}

  {{ log('', info=True) }}
  {{ log('📊 Schema Validation Summary:', info=True) }}
  {{ log('   Total tables validated: ' ~ total_tables ~ ' (' ~ models_count ~ ' models, ' ~ sources_count ~ ' sources)', info=True) }}
  {{ log('   Tables with matching schemas: ' ~ matching_tables, info=True) }}
  {{ log('   Tables with schema issues: ' ~ failed_tables, info=True) }}
  {{ log('   Tables not found in database: ' ~ tables_not_found, info=True) }}

  {{ return('') }}

{%- endmacro -%}

/*
  Macro to create a schema validation report as a table.
  This calls the main validation macro and should only be used in run-operations.
*/

{%- macro create_schema_validation_report() -%}
  {{ validate_all_schemas() }}
{%- endmacro -%}

/*
  Macro to get schema validation errors only.
  Useful for CI/CD pipelines where you only want to see failures.
  Now includes both models and sources.
*/

{%- macro get_schema_validation_errors() -%}

  {%- if not graph or not graph.nodes -%}
    {{ log("Error: This macro requires access to the dbt graph. Use 'dbt run-operation get_schema_validation_errors' instead.", info=True) }}
    {{ return("") }}
  {%- endif -%}

  -- Get all table column information in a single query
  {%- set table_columns_info = _get_all_table_columns() -%}

  {%- set tables_with_errors = [] -%}

  -- Check models
  {%- for node_id, node in graph.nodes.items() -%}
    {%- if node.resource_type == 'model' and node.columns -%}
      {%- set result = _validate_single_table_schema(node, table_columns_info, 'model') -%}

      {%- if result.validation_status not in ['SCHEMA_MATCH', 'TABLE_NOT_FOUND'] -%}
        {%- do tables_with_errors.append(result.table_name) -%}
        {{ log('❌ Model ' ~ result.table_name ~ ':', info=True) }}
        {%- if result.documented_but_missing_columns | length > 0 -%}
          {{ log('   • Documented but missing columns: ' ~ result.documented_but_missing_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.undocumented_columns | length > 0 -%}
          {{ log('   • Undocumented columns: ' ~ result.undocumented_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.data_type_mismatches | length > 0 -%}
          {{ log('   • Data type mismatches:', info=True) }}
          {%- for mismatch in result.data_type_mismatches -%}
            {{ log('     - ' ~ mismatch, info=True) }}
          {%- endfor -%}
        {%- endif -%}
      {%- elif result.validation_status == 'TABLE_NOT_FOUND' -%}
        {{ log('⚠️  Model ' ~ result.table_name ~ ': Model not found in database (may not be built yet)', info=True) }}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}

  -- Check sources
  {%- for source_id, source in graph.sources.items() -%}
    {%- if source.columns -%}
      {%- set result = _validate_single_table_schema(source, table_columns_info, 'source') -%}

      {%- if result.validation_status not in ['SCHEMA_MATCH', 'TABLE_NOT_FOUND'] -%}
        {%- do tables_with_errors.append(result.table_name) -%}
        {{ log('❌ Source ' ~ result.table_name ~ ':', info=True) }}
        {%- if result.documented_but_missing_columns | length > 0 -%}
          {{ log('   • Documented but missing columns: ' ~ result.documented_but_missing_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.undocumented_columns | length > 0 -%}
          {{ log('   • Undocumented columns: ' ~ result.undocumented_columns | join(', '), info=True) }}
        {%- endif -%}
        {%- if result.data_type_mismatches | length > 0 -%}
          {{ log('   • Data type mismatches:', info=True) }}
          {%- for mismatch in result.data_type_mismatches -%}
            {{ log('     - ' ~ mismatch, info=True) }}
          {%- endfor -%}
        {%- endif -%}
      {%- elif result.validation_status == 'TABLE_NOT_FOUND' -%}
        {{ log('⚠️  Source ' ~ result.table_name ~ ': Source not found in database', info=True) }}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}

  {%- if tables_with_errors | length == 0 -%}
    {{ log('✅ No schema validation errors found!', info=True) }}
  {%- else -%}
    {{ log('', info=True) }}
    {{ log('📊 Found ' ~ tables_with_errors | length ~ ' tables with schema validation errors', info=True) }}
    {{ exceptions.raise_compiler_error('Schema validation failed! ' ~ tables_with_errors | length ~ ' tables have schema mismatches.') }}
  {%- endif -%}

{%- endmacro -%}
