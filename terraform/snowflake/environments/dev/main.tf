############################
#         Variables        #
############################

variable "environment" {
  description = "Environment suffix"
  type        = string
}

variable "locator" {
  description = "Snowflake account locator"
  type        = string
}

############################
#         Providers        #
############################

terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "0.69"
    }
  }
  required_version = ">= 1.0"

  backend "s3" {
  }
}

# This provider is intentionally low-permission. In Snowflake, object creators are
# the default owners of the object. To control the owner, we create different provider
# blocks with different roles, and require that all snowflake resources explicitly
# flag the role they want for the creator.
provider "snowflake" {
  account = var.locator
  role    = "PUBLIC"
}

# Snowflake provider for creating databases, warehouses, etc.
provider "snowflake" {
  alias   = "sysadmin"
  account = var.locator
  role    = "SYSADMIN"
}

# Snowflake provider for managing grants to roles.
provider "snowflake" {
  alias   = "securityadmin"
  account = var.locator
  role    = "SECURITYADMIN"
}

# Snowflake provider for managing user accounts and roles.
provider "snowflake" {
  alias   = "useradmin"
  account = var.locator
  role    = "USERADMIN"
}

############################
#       Environment        #
############################

module "elt" {
  source = "../../modules/elt"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  environment = var.environment
}
