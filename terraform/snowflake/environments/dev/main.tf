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
  role    = "PUBLIC"
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource"]
}

# Snowflake provider for account administration (to be used only when necessary).
provider "snowflake" {
  alias   = "accountadmin"
  role    = "ACCOUNTADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource"]
}

# Snowflake provider for creating databases, warehouses, etc.
provider "snowflake" {
  alias   = "sysadmin"
  role    = "SYSADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource"]
}

# Snowflake provider for managing grants to roles.
provider "snowflake" {
  alias   = "securityadmin"
  role    = "SECURITYADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource"]
}

# Snowflake provider for managing user accounts and roles.
provider "snowflake" {
  alias   = "useradmin"
  role    = "USERADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource"]
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

##############################################################
# Assign LOGGER role to TRANSFORMER role
# This is only needed for the ODI default snowflake instance
# More backgorund information related to this is found
# here - https://github.com/cagov/data-infrastructure/issues/428
##############################################################

resource "snowflake_grant_account_role" "logger_to_transformer" {
  provider         = snowflake.useradmin
  role_name        = "LOGGER_${var.environment}"
  parent_role_name = "TRANSFORMER_${var.environment}"
}

# Default user password policy
resource "snowflake_password_policy" "user_password_policy" {
  database             = "POLICIES" # Database name
  schema               = "PUBLIC"   # Schema name
  name                 = "user_password_policy"
  min_length           = 14
  min_upper_case_chars = 1
  min_lower_case_chars = 1
  min_numeric_chars    = 1
  min_special_chars    = 1
  max_retries          = 5
  lockout_time_mins    = 30
  history              = 5
  max_age_days         = 60
  or_replace           = true # Ensures the policy can be updated without errors
}

# Set the default password policy for the account
resource "snowflake_account_password_policy_attachment" "attachment" {
  password_policy = snowflake_password_policy.user_password_policy.fully_qualified_name
}
