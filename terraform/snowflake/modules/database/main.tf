######################################
#            Terraform               #
######################################

terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.88"
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
      "TRUNCATE",
      "UPDATE",
    ]
  }

  # Access control permissions for view objects
  view = {
    READ             = ["SELECT", "REFERENCES"]
    READWRITE        = ["SELECT", "REFERENCES"]
    READWRITECONTROL = ["SELECT", "REFERENCES"]
  }
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
    prevent_destroy = false
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

resource "snowflake_grant_account_role" "this_to_sysadmin" {
  provider         = snowflake.useradmin
  for_each         = toset(keys(local.database))
  role_name        = snowflake_role.this[each.key].name
  parent_role_name = "SYSADMIN"
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

# TODO: ownership grants on all and future tables

# Database grants
resource "snowflake_grant_privileges_to_account_role" "database" {
  provider          = snowflake.securityadmin
  for_each          = local.database
  privileges        = each.value
  account_role_name = snowflake_role.this[each.key].name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.this.name
  }
  with_grant_option = false
}

# Schema grants
resource "snowflake_grant_ownership" "schemas" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_role.this["READWRITECONTROL"].name
  on {
    future {
      object_type_plural = "SCHEMAS"
      in_database        = snowflake_database.this.name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "schemas" {
  provider          = snowflake.securityadmin
  for_each          = local.schema
  privileges        = each.value
  account_role_name = snowflake_role.this[each.key].name
  on_schema {
    future_schemas_in_database = snowflake_database.this.name
  }
  with_grant_option = false
}

resource "snowflake_grant_privileges_to_account_role" "public" {
  provider          = snowflake.securityadmin
  for_each          = local.schema
  privileges        = each.value
  account_role_name = snowflake_role.this[each.key].name
  on_schema {
    schema_name = "${snowflake_database.this.name}.PUBLIC"
  }
  with_grant_option = false
}

# Table grants
resource "snowflake_grant_ownership" "tables" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_role.this["READWRITECONTROL"].name
  on {
    future {
      object_type_plural = "TABLES"
      in_database        = snowflake_database.this.name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "tables" {
  provider          = snowflake.securityadmin
  for_each          = local.table
  privileges        = each.value
  account_role_name = snowflake_role.this[each.key].name
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_database        = snowflake_database.this.name
    }
  }
  with_grant_option = false
}

# View grants
resource "snowflake_grant_ownership" "views" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_role.this["READWRITECONTROL"].name
  on {
    future {
      object_type_plural = "VIEWS"
      in_database        = snowflake_database.this.name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "views" {
  provider          = snowflake.securityadmin
  for_each          = local.view
  privileges        = each.value
  account_role_name = snowflake_role.this[each.key].name
  on_schema_object {
    future {
      object_type_plural = "VIEWS"
      in_database        = snowflake_database.this.name
    }
  }
  with_grant_option = false
}
