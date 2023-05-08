######################################
#            Terraform               #
######################################

terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.61"
      configuration_aliases = [
        snowflake.securityadmin,
        snowflake.sysadmin,
        snowflake.useradmin,
      ]
    }
  }
  required_version = ">= 1.0"
}

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

  # Access control permissions for view objects
  view = {
    READ             = ["SELECT", "REFERENCES"]
    READWRITE        = ["SELECT", "REFERENCES"]
    READWRITECONTROL = ["SELECT", "REFERENCES", "OWNERSHIP"]
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
  view_permissions = flatten([
    for type in keys(local.view) : [
      for privilege in local.view[type] : {
        type      = type
        privilege = privilege
      }
    ]
  ])
}

#######################################
#            Databases                #
#######################################

resource "snowflake_database" "this" {
  provider                    = snowflake.sysadmin
  name                        = var.name
  comment                     = var.comment
  data_retention_time_in_days = var.data_retention_time_in_days

  lifecycle {
    prevent_destroy = true
  }
}

######################################
#            Access Roles            #
######################################

resource "snowflake_role" "this" {
  provider = snowflake.useradmin
  for_each = toset(keys(local.database))
  name     = "${snowflake_database.this.name}_${each.key}"
  comment  = "${each.key} access to ${snowflake_database.this.name}"
}

######################################
#            Role Grants             #
######################################

resource "snowflake_role_grants" "this_to_sysadmin" {
  provider               = snowflake.useradmin
  for_each               = toset(keys(local.database))
  role_name              = snowflake_role.this[each.key].name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
  depends_on             = [snowflake_role.this]
}

######################################
#   Database/Schema/Table Grants     #
######################################

# The strategy taken here is to loop over every single access control type
# (READ, READWRITE, READWRITECONTROL) + permission (e.g. SELECT) combination,
# and create a role grant for that combination. This generates a lot of grants!
#
# Schema, table, and view grants also get the on_future=true flag, which means that the
# roles created here also get the same permissions in newly-created schemas and tables.
# https://community.snowflake.com/s/article/How-to-grant-select-on-all-future-tables-in-a-schema-and-database-level

# Database grants
resource "snowflake_database_grant" "this" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.this.name
  for_each               = { for p in local.database_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  roles                  = ["${snowflake_database.this.name}_${each.value.type}"]
  depends_on             = [snowflake_role.this]
}

# Schema grants
resource "snowflake_schema_grant" "this" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.this.name
  for_each               = { for p in local.schema_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.this.name}_${each.value.type}"]
  depends_on             = [snowflake_role.this]
}

# Table grants
resource "snowflake_table_grant" "this" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.this.name
  for_each               = { for p in local.table_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.this.name}_${each.value.type}"]
  depends_on             = [snowflake_role.this]
}

# View grants
resource "snowflake_view_grant" "this" {
  provider               = snowflake.securityadmin
  database_name          = snowflake_database.this.name
  for_each               = { for p in local.view_permissions : "${p.type}-${p.privilege}" => p }
  privilege              = each.value.privilege
  enable_multiple_grants = true
  on_future              = true
  roles                  = ["${snowflake_database.this.name}_${each.value.type}"]
  depends_on             = [snowflake_role.this]
}
