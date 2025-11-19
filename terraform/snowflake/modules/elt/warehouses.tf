#################################
#           Warehouses          #
#################################

#X-Small: Good for small tasks and experimenting.
#Small: Suitable for single-user workloads and development.
#Medium: Handles moderate concurrency and data volumes.
#Large: Manages larger queries and higher concurrency.
#X-Large: Powerful for demanding workloads and data-intensive operations.
#2X-Large: Double the capacity of X-Large.
#3X-Large: Triple the capacity of X-Large.
#4X-Large: Quadruple the capacity of X-Large.

locals {
  sizes = {
    "XS"  = "X-SMALL",
    "S"   = "SMALL",
    "M"   = "MEDIUM",
    "L"   = "LARGE",
    "XL"  = "X-LARGE",
    "2XL" = "2X-LARGE",
    "3XL" = "3X-LARGE",
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
