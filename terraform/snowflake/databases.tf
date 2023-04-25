######################################
#           Permissions              #
######################################

# https://community.snowflake.com/s/article/How-to-grant-select-on-all-future-tables-in-a-schema-and-database-level

locals {
  // https://docs.snowflake.com/en/sql-reference/sql/grant-privilege.html
  database = {
    READ             = ["USAGE"]
    READWRITE        = ["USAGE"]
    READWRITECONTROL = ["USAGE", "CREATE SCHEMA"]
  }
  schema = {
    READ      = ["USAGE"]
    READWRITE = ["USAGE"]
    READWRITECONTROL = [
      "CREATE FILE FORMAT",
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
      "USAGE",
    ]
  }
  table = {
    READ = ["SELECT", "REFERENCES"]
    READWRITE = [
      "DELETE",
      "INSERT",
      "TRUNCATE",
      "UPDATE",
    ]
    READWRITECONTROL = [
      "DELETE",
      "INSERT",
      "OWNERSHIP",
      "TRUNCATE",
      "UPDATE",
    ]
  }

  # Create objects for each access control - privilege combination.
  # We will use them for assigning access role grants below.
  database_permissions = flatten([
    for type in keys(local.database) : [
      for privilege in local.database[type] : {
        type      = type
        privilege = privilege
      }
    ]
  ])
  schema_permissions = flatten([
    for type in keys(local.schema) : [
      for privilege in local.schema[type] : {
        type      = type
        privilege = privilege
      }
    ]
  ])
  table_permissions = flatten([
    for type in keys(local.table) : [
      for privilege in local.table[type] : {
        type      = type
        privilege = privilege
      }
    ]
  ])
}

#######################################
#            Databases                #
#######################################

resource "snowflake_database" "transform" {
  provider                    = snowflake.sysadmin
  name                        = "TRANSFORM"
  comment                     = "Transformation database"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "snowflake_database" "raw" {
  provider                    = snowflake.sysadmin
  name                        = "RAW"
  comment                     = "Raw database, intended for ingest of raw data from source systems prior to any modeling or transformation"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "snowflake_database" "analytics" {
  provider                    = snowflake.sysadmin
  name                        = "ANALYTICS"
  comment                     = "Analytics database for data consumers, holding analysis-ready data marts/models"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

######################################
#            Access Roles            #
######################################

resource "snowflake_role" "raw" {
  provider = snowflake.useradmin
  for_each = toset(keys(local.database))
  name     = "${snowflake_database.raw.name}_${each.key}"
  comment  = "${each.key} access to ${snowflake_database.raw.name}"
}

resource "snowflake_role" "transform" {
  provider = snowflake.useradmin
  for_each = toset(keys(local.database))
  name     = "${snowflake_database.transform.name}_${each.key}"
  comment  = "${each.key} access to ${snowflake_database.transform.name}"
}

resource "snowflake_role" "analytics" {
  provider = snowflake.useradmin
  for_each = toset(keys(local.database))
  name     = "${snowflake_database.analytics.name}_${each.key}"
  comment  = "${each.key} access to ${snowflake_database.analytics.name}"
}

######################################
#            Role Grants             #
######################################

resource "snowflake_role_grants" "raw_to_sysadmin" {
  provider               = snowflake.useradmin
  for_each               = toset(keys(local.database))
  role_name              = snowflake_role.raw[each.key].name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
  depends_on             = [snowflake_role.raw]
}

resource "snowflake_role_grants" "transform_to_sysadmin" {
  provider               = snowflake.useradmin
  for_each               = toset(keys(local.database))
  role_name              = snowflake_role.transform[each.key].name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
  depends_on             = [snowflake_role.transform]
}

resource "snowflake_role_grants" "analytics_to_sysadmin" {
  provider               = snowflake.useradmin
  for_each               = toset(keys(local.database))
  role_name              = snowflake_role.analytics[each.key].name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
  depends_on             = [snowflake_role.analytics]
}


######################################
#   Database/Schema/Table Grants     #
######################################

resource "snowflake_database_grant" "raw" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.raw.name
  for_each               = { for p in local.database_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  roles                  = ["${snowflake_database.raw.name}_${each.value.type}"]
  depends_on             = [snowflake_role.raw]
}

resource "snowflake_database_grant" "transform" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.transform.name
  for_each               = { for p in local.database_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  roles                  = ["${snowflake_database.transform.name}_${each.value.type}"]
  depends_on             = [snowflake_role.transform]
}

resource "snowflake_database_grant" "analytics" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.analytics.name
  for_each               = { for p in local.database_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  roles                  = ["${snowflake_database.analytics.name}_${each.value.type}"]
  depends_on             = [snowflake_role.analytics]
}

resource "snowflake_schema_grant" "raw" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.raw.name
  for_each               = { for p in local.schema_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.raw.name}_${each.value.type}"]
  depends_on             = [snowflake_role.raw]
}

resource "snowflake_schema_grant" "transform" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.transform.name
  for_each               = { for p in local.schema_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.transform.name}_${each.value.type}"]
  depends_on             = [snowflake_role.transform]
}

resource "snowflake_schema_grant" "analytics" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.analytics.name
  for_each               = { for p in local.schema_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.analytics.name}_${each.value.type}"]
  depends_on             = [snowflake_role.analytics]
}

resource "snowflake_table_grant" "raw" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.raw.name
  for_each               = { for p in local.table_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.raw.name}_${each.value.type}"]
  depends_on             = [snowflake_role.raw]
}

resource "snowflake_table_grant" "transform" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.transform.name
  for_each               = { for p in local.table_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.transform.name}_${each.value.type}"]
  depends_on             = [snowflake_role.transform]
}

resource "snowflake_table_grant" "analytics" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.analytics.name
  for_each               = { for p in local.table_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.analytics.name}_${each.value.type}"]
  depends_on             = [snowflake_role.analytics]
}
