#################################
#           Warehouses          #
#################################

locals {
  sizes = {
    "XS"  = "X-SMALL",
    "XL"  = "X-LARGE",
    "4XL" = "4X-LARGE",
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

# Primary warehouse for logging. Logging tools like Sentinel should use this warehouse.
module "logging" {
  source = "../warehouse"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name         = "LOGGING_XS_${var.environment}"
  comment      = "Primary warehouse for logging. Logging tools like Sentinel should use this warehouse."
  size         = "X-SMALL"
  auto_suspend = 1
}
