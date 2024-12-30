######################################
#            Terraform               #
######################################

terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 1.0"
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

locals {
  # Permissions to use a data warehouse. No role is given the MODIFY permission,
  # instead warehouses should be treated as stateless, and if we need a larger
  # one it should be created individually.
  warehouse = {
    MOU = ["MONITOR", "OPERATE", "USAGE"]
  }
}

#################################
#           Warehouses          #
#################################


resource "snowflake_warehouse" "this" {
  name                = var.name
  provider            = snowflake.sysadmin
  auto_suspend        = var.auto_suspend
  auto_resume         = true
  initially_suspended = true
  comment             = var.comment
  warehouse_size      = var.size
}

#################################
#     Warehouse Access Roles    #
#################################

# Monitoring, usage, and operating permissions for the LOADING warehouse.
resource "snowflake_account_role" "this" {
  name     = "${var.name}_WH_MOU"
  provider = snowflake.useradmin
  comment  = "Monitoring, usage, and operating permissions for the ${var.name} warehouse"
}

#################################
#          Role Grants          #
#################################

resource "snowflake_grant_account_role" "this_to_sysadmin" {
  provider         = snowflake.useradmin
  role_name        = snowflake_account_role.this.name
  parent_role_name = "SYSADMIN"
}

#################################
#       Warehouse Grants        #
#################################

resource "snowflake_grant_privileges_to_account_role" "this" {
  provider          = snowflake.securityadmin
  privileges        = local.warehouse.MOU
  account_role_name = snowflake_account_role.this.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.this.name
  }
  with_grant_option = false
}
