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
  role    = "PUBLIC"
}

# Snowflake provider for account administration (to be used only when necessary).
provider "snowflake" {
  alias   = "accountadmin"
  role    = "ACCOUNTADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource", "snowflake_account_password_policy_attachment_resource", "snowflake_account_authentication_policy_attachment_resource"]
}

# Snowflake provider for creating databases, warehouses, etc.
provider "snowflake" {
  alias   = "sysadmin"
  role    = "SYSADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
}

# Snowflake provider for managing grants to roles.
provider "snowflake" {
  alias   = "securityadmin"
  role    = "SECURITYADMIN"
  account_name      = var.account_name
  organization_name = var.organization_name
  preview_features_enabled = ["snowflake_authentication_policy_resource", "snowflake_password_policy_resource", "snowflake_account_password_policy_attachment_resource","snowflake_account_authentication_policy_attachment_resource"]
}

# Snowflake provider for managing user accounts and roles.
provider "snowflake" {
  alias   = "useradmin"
  role    = "USERADMIN"
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
// Create the POLICIES database to store the password policy
resource "snowflake_database" "policies" {
  name = "POLICIES"
}

# Default user password policy
resource "snowflake_password_policy" "user_password_policy" {
  provider             = snowflake.accountadmin
  database             = snowflake_database.policies.name # Database name
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
  or_replace           = true # Ensures the policy can be updated without errors
}

# Set the default password policy for the account
resource "snowflake_account_password_policy_attachment" "attachment" {
  provider        = snowflake.accountadmin
  password_policy = snowflake_password_policy.user_password_policy.fully_qualified_name
}

// Defines an authentication policy for ODI human users that enforces Okta-only authentication via SAML.
resource "snowflake_authentication_policy" "odi_okta_only" {
  count = var.okta_integration_name == null ? 0 : 1 // meta-argument to conditionally create the resource
  provider                   = snowflake.accountadmin
  database                   = snowflake_database.policies.name # Database name
  schema                     = "PUBLIC"   # Schema name
  name                       = "odi_okta_only"
  authentication_methods     = ["SAML"]
  security_integrations      = [var.okta_integration_name] # Okta security integration name
  comment                    = "Okta-only authentication policy for ODI human users"
}

// Defines an authentication policy for external human users that enforces password-based authentication with Duo MFA.
resource "snowflake_authentication_policy" "external_duo_mfa" {
  provider                   = snowflake.accountadmin
  database                   = snowflake_database.policies.name # Database name
  schema                     = "PUBLIC"   # Schema name
  name                       = "external_duo_mfa"
  authentication_methods     = ["PASSWORD"]
  mfa_authentication_methods = ["PASSWORD"]
  mfa_enrollment             = "REQUIRED"
  client_types               = ["SNOWFLAKE_UI", "DRIVERS", "SNOWSQL"] # MFA enrollment requires SNOWFLAKE_UI
  comment                    = "Duo-MFA-only authentication policy for external human users"
}

// Defines an authentication policy for admin human users that allows both Okta SAML and password-based authentication with Duo MFA.
resource "snowflake_authentication_policy" "admin_okta_duo" {
  count = var.okta_integration_name == null ? 0 : 1 // meta-argument to conditionally create the resource
  provider                   = snowflake.accountadmin
  database                   = snowflake_database.policies.name # Database name
  schema                     = "PUBLIC"   # Schema name
  name                       = "admin_okta_duo"
  authentication_methods     = ["SAML", "PASSWORD"]
  mfa_authentication_methods = ["PASSWORD"]
  mfa_enrollment             = "REQUIRED"
  client_types               = ["SNOWFLAKE_UI", "DRIVERS", "SNOWSQL"]
  security_integrations      = [var.okta_integration_name] # Okta security integration name
  comment                    = "Okta and Duo-MFA authentication policy for admin human users"
}

// Defines an authentication policy for most service accounts that enforces key-pair authentication.
resource "snowflake_authentication_policy" "service_account_keypair" {
  provider                   = snowflake.accountadmin
  database                   = snowflake_database.policies.name # Database name
  schema                     = "PUBLIC"   # Schema name
  name                       = "service_account_keypair"
  authentication_methods     = ["KEYPAIR"]
  client_types               = ["DRIVERS", "SNOWSQL"]
  comment                    = "Key-pair only authentication policy for most service accounts"
}

// Defines an authentication policy for legacy service accounts that enforces password-based authentication.
resource "snowflake_authentication_policy" "legacy_service_password" {
  provider                   = snowflake.accountadmin
  database                   = snowflake_database.policies.name # Database name
  schema                     = "PUBLIC"   # Schema name
  name                       = "legacy_service_password"
  authentication_methods     = ["PASSWORD"]
  client_types               = ["DRIVERS", "SNOWSQL"]
  comment                    = "Password-only authentication policy for legacy service accounts"
}

# Set odi_okta_only as the default authentication policy for the account
resource "snowflake_account_authentication_policy_attachment" "default_policy" {
  count = var.okta_integration_name == null ? 0 : 1
  provider                   = snowflake.accountadmin
  authentication_policy      = snowflake_authentication_policy.odi_okta_only[0].fully_qualified_name // using the first and only instance that gets created
}
