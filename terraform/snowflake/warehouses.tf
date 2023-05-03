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

# Primary warehouse for loading data to Snowflake from ELT/ETL tools
resource "snowflake_warehouse" "loading" {
  name                = "LOADING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for loading data to Snowflake from ELT/ETL tools"
  warehouse_size      = "x-small"
}

# Primary warehouse for transforming data. Analytics engineers and automated
# transformation tools should use this warehouse.
resource "snowflake_warehouse" "transforming" {
  name                = "TRANSFORMING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for transforming data. Analytics engineers and automated transformation tools should use this warehouse"
  warehouse_size      = "x-small"
}

# Primary warehouse for reporting. End-users and BI tools should use this warehouse.
resource "snowflake_warehouse" "reporting" {
  name                = "REPORTING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for reporting. End-users and BI tools should use this warehouse"
  warehouse_size      = "x-small"
}

#################################
#     Warehouse Access Roles    #
#################################

# Monitoring, usage, and operating permissions for the LOADING warehouse.
resource "snowflake_role" "loading" {
  name     = "${snowflake_warehouse.loading.name}_WH_MOU"
  provider = snowflake.useradmin
  comment  = "Monitoring, usage, and operating permissions for the LOADING warehouse"
}

# Monitoring, usage, and operating permissions for the TRANSFORMING warehouse.
resource "snowflake_role" "transforming" {
  name     = "${snowflake_warehouse.transforming.name}_WH_MOU"
  provider = snowflake.useradmin
  comment  = "Monitoring, usage, and operating permissions for the TRANSFORMING warehouse"
}

# Monitoring, usage, and operating permissions for the REPORTING warehouse.
resource "snowflake_role" "reporting" {
  name     = "${snowflake_warehouse.reporting.name}_WH_MOU"
  provider = snowflake.useradmin
  comment  = "Monitoring, usage, and operating permissions for the REPORTING warehouse"
}

#################################
#          Role Grants          #
#################################

resource "snowflake_role_grants" "loading_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.loading.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

resource "snowflake_role_grants" "transforming_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.transforming.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

resource "snowflake_role_grants" "reporting_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.reporting.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

#################################
#       Warehouse Grants        #
#################################

# Allow the loading access role to use the loading warehouse
resource "snowflake_warehouse_grant" "loader" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.warehouse.MOU)
  warehouse_name    = snowflake_warehouse.loading.name
  privilege         = each.key
  roles             = [snowflake_role.loading.name]
  with_grant_option = false
}

# Allow the transforming access role to use the transforming warehouse
resource "snowflake_warehouse_grant" "transformer" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.warehouse.MOU)
  warehouse_name    = snowflake_warehouse.transforming.name
  privilege         = each.key
  roles             = [snowflake_role.transforming.name]
  with_grant_option = false
}

# Allow the reporting access role to use the reporting warehouse
resource "snowflake_warehouse_grant" "reporter" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.warehouse.MOU)
  warehouse_name    = snowflake_warehouse.reporting.name
  privilege         = each.key
  roles             = [snowflake_role.reporting.name]
  with_grant_option = false
}
