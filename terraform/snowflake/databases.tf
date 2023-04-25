######################################
#           Permissions              #
######################################

# WARNING! An earlier version of these access control types used abbreviated names
# for them, e.g. RWC instead of READWRITECONTROL. This ran into trouble with a pretty
# gnarly bug in the Snowflake terraform provider, where object names with underscores
# in them are not properly handled, and are treated as wildcards. So there could be
# name collisions in the terraform state where, e.g., TRANSFORMER was equivalent to
# TRANSFORM_R. To avoid this until a proper fix is in place, we just create longer
# access control type names which are much less likely to collide accidentally.
# This solution stinks.
#
# Some more reading:
# https://github.com/Snowflake-Labs/terraform-provider-snowflake/issues/1527
# https://github.com/Snowflake-Labs/terraform-provider-snowflake/issues/1241

locals {
  # Access control permissions for database objects.
  database = {
    READ             = ["USAGE"]
    READWRITE        = ["USAGE"]
    READWRITECONTROL = ["USAGE", "CREATE SCHEMA"]
  }

  # Access control permissions for schema objects.
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

  # Access control permissions for table objects.
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

# The primary database where transformation tools like dbt operate.
resource "snowflake_database" "transform" {
  provider                    = snowflake.sysadmin
  name                        = "TRANSFORM"
  comment                     = "Transformation database"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

# The primary raw database, where ELT tools land data.
resource "snowflake_database" "raw" {
  provider                    = snowflake.sysadmin
  name                        = "RAW"
  comment                     = "Raw database, intended for ingest of raw data from source systems prior to any modeling or transformation"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

# The primary reporting database.
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

# Access roles for the RAW database.
resource "snowflake_role" "raw" {
  provider = snowflake.useradmin
  for_each = toset(keys(local.database))
  name     = "${snowflake_database.raw.name}_${each.key}"
  comment  = "${each.key} access to ${snowflake_database.raw.name}"
}

# Access roles for the TRANSFORM database.
resource "snowflake_role" "transform" {
  provider = snowflake.useradmin
  for_each = toset(keys(local.database))
  name     = "${snowflake_database.transform.name}_${each.key}"
  comment  = "${each.key} access to ${snowflake_database.transform.name}"
}

# Access roles for the ANALYTICS database.
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

# The strategy taken here is to loop over every single access control type
# (READ, READWRITE, READWRITECONTROL) + permission (e.g. SELECT) combination,
# and create a role grant for that combination. This generates a lot of grants!
#
# Schema and table grants also get the on_future=true flag, which means that the roles
# created here also get the same permissions in newly-created schemas and tables.
# https://community.snowflake.com/s/article/How-to-grant-select-on-all-future-tables-in-a-schema-and-database-level

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
