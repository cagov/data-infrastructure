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
resource "snowflake_role" "this" {
  name     = "${var.name}_WH_MOU"
  provider = snowflake.useradmin
  comment  = "Monitoring, usage, and operating permissions for the ${var.name} warehouse"
}

#################################
#          Role Grants          #
#################################

resource "snowflake_role_grants" "this_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.this.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

#################################
#       Warehouse Grants        #
#################################

resource "snowflake_warehouse_grant" "this" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.warehouse.MOU)
  warehouse_name    = snowflake_warehouse.this.name
  privilege         = each.key
  roles             = [snowflake_role.this.name]
  with_grant_option = false
}
