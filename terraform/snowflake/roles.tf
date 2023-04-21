######################################
#           Permissions              #
######################################

locals {
  // https://docs.snowflake.com/en/sql-reference/sql/grant-privilege.html
  admin = {
    database = ["CREATE SCHEMA"]
    schema = [
      "CREATE MATERIALIZED VIEW",
      "CREATE PIPE",
      "CREATE PROCEDURE",
      "CREATE STAGE",
      "CREATE TABLE",
      "CREATE TEMPORARY TABLE",
      "CREATE VIEW",
      "MODIFY",
      "MONITOR",
      "OWNERSHIP",
    ]
    table = [
      "DELETE",
      "INSERT",
      "TRUNCATE",
      "UPDATE",
    ]
  }
  read = {
    // Full application database
    database = ["USAGE"]
    schema   = ["USAGE"]
    table    = ["SELECT", "REFERENCES"]
    view     = ["SELECT", "REFERENCES"]
  }
  use = {
    warehouse = ["MONITOR", "OPERATE", "USAGE"]
  }
}

######################################
#           Base Roles               #
######################################

resource "snowflake_role" "loader" {
  provider = snowflake.useradmin
  name     = "LOADER"
  comment  = "Permissions to load data to the RAW database"
}

resource "snowflake_role" "transformer" {
  provider = snowflake.useradmin
  name     = "TRANSFORMER"
  comment  = "Permissions to read data from the RAW database, and read/write to TRANSFORM and ANALYTICS"
}

resource "snowflake_role" "reporter" {
  provider = snowflake.useradmin
  name     = "REPORTER"
  comment  = "Permissions to read data from the ANALYTICS database"
}


######################################
#           Roles Grants             #
######################################

# Grant our roles to the SYSADMIN user, per best practices:
# https://docs.snowflake.com/en/user-guide/security-access-control-considerations#aligning-object-access-with-business-functions
# This allows SYSADMIN to make additional grants of database objects to these roles.

resource "snowflake_role_grants" "loader" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.loader.name
  enable_multiple_grants = true
  roles = [
    "SYSADMIN",
  ]
}

resource "snowflake_role_grants" "transformer" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.transformer.name
  enable_multiple_grants = true
  roles = [
    "SYSADMIN",
  ]
}

resource "snowflake_role_grants" "reporter" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.reporter.name
  enable_multiple_grants = true
  roles = [
    "SYSADMIN",
  ]
}

######################################
#         Warehouse Grants           #
######################################

resource "snowflake_warehouse_grant" "loader" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.use.warehouse)
  warehouse_name    = snowflake_warehouse.loading.name
  privilege         = each.key
  roles             = [snowflake_role.loader.name]
  with_grant_option = false
}

resource "snowflake_warehouse_grant" "transformer" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.use.warehouse)
  warehouse_name    = snowflake_warehouse.transforming.name
  privilege         = each.key
  roles             = [snowflake_role.transformer.name]
  with_grant_option = false
}

resource "snowflake_warehouse_grant" "reporter" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.use.warehouse)
  warehouse_name    = snowflake_warehouse.reporting.name
  privilege         = each.key
  roles             = [snowflake_role.reporter.name]
  with_grant_option = false
}

######################################
#         Database Grants            #
######################################

# https://community.snowflake.com/s/article/How-to-grant-select-on-all-future-tables-in-a-schema-and-database-level

// Loader has admin privileges to create schemas and tables in RAW
resource "snowflake_database_grant" "loader_raw" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.raw.name
  privilege     = "USAGE"
  roles         = [snowflake_role.loader.name]
}

resource "snowflake_schema_grant" "loader_raw" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.raw.name
  for_each      = toset(local.admin.schema)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.loader.name]
}

resource "snowflake_table_grant" "loader_raw" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.raw.name
  for_each      = toset(local.admin.table)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.loader.name]
}

// Reporter has read privileges in ANALYTICS
resource "snowflake_database_grant" "reporter_analytics" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.analytics.name
  privilege     = "USAGE"
  roles         = [snowflake_role.reporter.name]
}

resource "snowflake_schema_grant" "reporter_analytics" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.analytics.name
  privilege     = "USAGE"
  on_future     = true
  roles         = [snowflake_role.reporter.name]
}

resource "snowflake_table_grant" "reporter_analytics" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.analytics.name
  for_each      = toset(local.read.table)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.reporter.name]
}

// Transformer has admin privileges in TRANSFORM
resource "snowflake_database_grant" "transformer_transform" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.transform.name
  privilege     = "USAGE"
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_schema_grant" "transformer_transform" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.transform.name
  for_each      = toset(local.admin.schema)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_table_grant" "transformer_transform" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.transform.name
  for_each      = toset(local.admin.table)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.transformer.name]
}

// Transformer has admin privileges in ANALYTICS
resource "snowflake_database_grant" "transformer_analytics" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.analytics.name
  privilege     = "USAGE"
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_schema_grant" "transformer_analytics" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.analytics.name
  for_each      = toset(local.admin.schema)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_table_grant" "transformer_analytics" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.analytics.name
  for_each      = toset(local.admin.table)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.transformer.name]
}

// Transformer has read permissions in RAW
resource "snowflake_database_grant" "transformer_raw" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.raw.name
  privilege     = "USAGE"
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_schema_grant" "transformer_raw" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.raw.name
  for_each      = toset(local.read.schema)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_table_grant" "transformer_raw" {
  provider      = snowflake.securityadmin
  database_name = snowflake_database.raw.name
  for_each      = toset(local.read.table)
  privilege     = each.key
  on_future     = true
  roles         = [snowflake_role.transformer.name]
}
