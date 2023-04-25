locals {
  warehouse = {
    MOU = ["MONITOR", "OPERATE", "USAGE"]
  }
}

#################################
#           Warehouses          #
#################################

resource "snowflake_warehouse" "loading" {
  name                = "LOADING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for loading data to Snowflake from ELT/ETL tools"
  warehouse_size      = "x-small"
}

resource "snowflake_warehouse" "transforming" {
  name                = "TRANSFORMING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for transforming data. Analytics engineers and automated transformation tools should use this warehouse"
  warehouse_size      = "x-small"
}

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

resource "snowflake_role" "loading" {
  name     = "LOADING_WH_MOU"
  provider = snowflake.useradmin
  comment  = "Monitoring, usage, and operating permissions for the LOADING warehouse"
}

resource "snowflake_role" "transforming" {
  name     = "TRANSFORMING_WH_MOU"
  provider = snowflake.useradmin
  comment  = "Monitoring, usage, and operating permissions for the TRANSFORMING warehouse"
}

resource "snowflake_role" "reporting" {
  name     = "REPORTING_WH_MOU"
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

resource "snowflake_warehouse_grant" "loader" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.warehouse.MOU)
  warehouse_name    = snowflake_warehouse.loading.name
  privilege         = each.key
  roles             = [snowflake_role.loader.name]
  with_grant_option = false
}

resource "snowflake_warehouse_grant" "transformer" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.warehouse.MOU)
  warehouse_name    = snowflake_warehouse.transforming.name
  privilege         = each.key
  roles             = [snowflake_role.transformer.name]
  with_grant_option = false
}

resource "snowflake_warehouse_grant" "reporter" {
  provider          = snowflake.securityadmin
  for_each          = toset(local.warehouse.MOU)
  warehouse_name    = snowflake_warehouse.reporting.name
  privilege         = each.key
  roles             = [snowflake_role.reporter.name]
  with_grant_option = false
}
