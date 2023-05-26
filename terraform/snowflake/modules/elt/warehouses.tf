#################################
#           Warehouses          #
#################################

locals {
  sizes = {
    "XS"  = "x-small",
    "XL"  = "x-large",
    "4XL" = "4x-large",
  }
}

# Primary warehouse for loading data to Snowflake from ELT/ETL tools
module "loading" {
  source   = "../warehouse"
  for_each = local.sizes
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "LOADING_${each.key}_${var.environment}"
  comment = "Primary warehouse for loading data to Snowflake from ELT/ETL tools"
  size    = each.value
}

# Primary warehouse for transforming data. Analytics engineers and automated
# transformation tools should use this warehouse.
module "transforming" {
  source   = "../warehouse"
  for_each = local.sizes
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "TRANSFORMING_${each.key}_${var.environment}"
  comment = "Primary warehouse for transforming data. Analytics engineers and automated transformation tools should use this warehouse"
  size    = each.value
}

# Primary warehouse for reporting. End-users and BI tools should use this warehouse.
module "reporting" {
  source   = "../warehouse"
  for_each = local.sizes
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "REPORTING_${each.key}_${var.environment}"
  comment = "Primary warehouse for reporting. End-users and BI tools should use this warehouse"
  size    = each.value
}
