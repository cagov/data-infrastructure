############################
#         Variables        #
############################

variable "environment" {
  description = "Environment suffix"
  type        = string
}

variable "account_name" {
  description = "Snowflake account name"
  type        = string
}

variable "organization_name" {
  description = "Snowflake account organization"
  type        = string
}

variable "okta_integration_name" {
  description = "The name of the Okta security integration. If null, the odi_okta_only authentication policy will not be created."
  type        = string
  default     = null
}

############################
#         Providers        #
############################

terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "1.0.1"
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
  account_name      = var.account_name
  organization_name = var.organization_name
  role              = "PUBLIC"
}

# Snowflake provider for account administration (to be used only when necessary).
provider "snowflake" {
  alias                    = "accountadmin"
  role                     = "ACCOUNTADMIN"
  account_name             = var.account_name
  organization_name        = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource", "snowflake_account_password_policy_attachment_resource", "snowflake_account_authentication_policy_attachment_resource"]
}

# Snowflake provider for creating databases, warehouses, etc.
provider "snowflake" {
  alias             = "sysadmin"
  role              = "SYSADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
}

# Snowflake provider for managing grants to roles.
provider "snowflake" {
  alias                    = "securityadmin"
  role                     = "SECURITYADMIN"
  account_name             = var.account_name
  organization_name        = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource", "snowflake_account_password_policy_attachment_resource", "snowflake_account_authentication_policy_attachment_resource"]
}

# Snowflake provider for managing user accounts and roles.
provider "snowflake" {
  alias             = "useradmin"
  role              = "USERADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
}

############################
#       Environment        #
############################

module "elt" {
  source = "../../modules/elt"
  providers = {
    snowflake.accountadmin  = snowflake.accountadmin,
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  environment = var.environment
}

module "policies" {
  source = "../../modules/policies"
  # pass the aliased provider the module expects
  providers = {
    snowflake.accountadmin  = snowflake.accountadmin,
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }
  # inputs
  okta_integration_name  = var.okta_integration_name
  policies_database_name = "POLICIES"
}
