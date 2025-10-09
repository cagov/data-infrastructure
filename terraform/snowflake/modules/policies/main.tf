######################################
#            Terraform               #
######################################
# This module enforces Snowflake security by creating a POLICIES database,
# defining strong default password/authentication policies for different user types,
# setting Okta-only auth as the default (when enabled), and provisioning a Sentinel
# legacy service user with the required role grants.
############################
#         Providers        #
############################

terraform {
  required_version = ">= 1.0"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = ">= 1.0.1"
      configuration_aliases = [
        snowflake.accountadmin,
        snowflake.securityadmin,
        snowflake.sysadmin,
        snowflake.useradmin,
      ]
    }
  }
}

# POLICIES database (import if it already exists)
resource "snowflake_database" "policies" {
  provider = snowflake.accountadmin
  name     = var.policies_database_name
  # import hint:
  # terraform import module.policies.snowflake_database.policies POLICIES
}

# account-level role & warehouse (no env vars)
resource "snowflake_account_role" "logger" {
  provider = snowflake.securityadmin
  name     = "LOGGER_PRD"
  comment  = "Account-level role for logging tasks"
}

resource "snowflake_warehouse" "logging" {
  provider            = snowflake.sysadmin
  name                = "LOGGING_PRD_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Warehouse used by Sentinel/logging tasks (PRD)"
}

# ßSentinel service user
resource "snowflake_legacy_service_user" "sentinel" {
  provider = snowflake.useradmin
  name     = "SENTINEL_SVC_USER"
  comment  = "Service user for Sentinel"

  lifecycle { ignore_changes = [rsa_public_key] }

  default_warehouse = snowflake_warehouse.logging.name
  default_role      = snowflake_account_role.logger.name
}

# Grant LOGGER_PRD to Sentinel
resource "snowflake_grant_account_role" "logger_to_sentinel" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.logger.name
  user_name = snowflake_legacy_service_user.sentinel.name
}

# Default user password policy
resource "snowflake_password_policy" "user_password_policy" {
  provider             = snowflake.accountadmin
  database             = snowflake_database.policies.name
  schema               = "PUBLIC"
  name                 = "user_password_policy"
  min_length           = 14
  min_upper_case_chars = 1
  min_lower_case_chars = 1
  min_numeric_chars    = 1
  min_special_chars    = 1
  max_retries          = 5
  lockout_time_mins    = 30
  history              = 5
  or_replace           = true
}

# Attach password policy at account level
resource "snowflake_account_password_policy_attachment" "attachment" {
  provider        = snowflake.accountadmin
  password_policy = snowflake_password_policy.user_password_policy.fully_qualified_name
}

# Auth policies (Okta-only for human users, etc.)
resource "snowflake_authentication_policy" "odi_okta_only" {
  count                  = var.okta_integration_name == null ? 0 : 1
  provider               = snowflake.accountadmin
  database               = snowflake_database.policies.name
  schema                 = "PUBLIC"
  name                   = "odi_okta_only"
  authentication_methods = ["SAML"]
  security_integrations  = [var.okta_integration_name]
  comment                = "Okta-only authentication policy for ODI human users (PRD)"
}

resource "snowflake_authentication_policy" "admin_okta_duo" {
  count                      = var.okta_integration_name == null ? 0 : 1
  provider                   = snowflake.accountadmin
  database                   = snowflake_database.policies.name
  schema                     = "PUBLIC"
  name                       = "admin_okta_duo"
  authentication_methods     = ["SAML", "PASSWORD"]
  mfa_authentication_methods = ["PASSWORD"]
  mfa_enrollment             = "REQUIRED"
  client_types               = ["SNOWFLAKE_UI", "DRIVERS", "SNOWSQL"]
  security_integrations      = [var.okta_integration_name]
  comment                    = "Okta and Duo-MFA policy for admin users (PRD)"
}

resource "snowflake_authentication_policy" "external_duo_mfa" {
  provider                   = snowflake.accountadmin
  database                   = snowflake_database.policies.name
  schema                     = "PUBLIC"
  name                       = "external_duo_mfa"
  authentication_methods     = ["PASSWORD"]
  mfa_authentication_methods = ["PASSWORD"]
  mfa_enrollment             = "REQUIRED"
  client_types               = ["SNOWFLAKE_UI", "DRIVERS", "SNOWSQL"]
  comment                    = "Duo-MFA-only authentication policy for external human users (PRD)"
}

resource "snowflake_authentication_policy" "service_account_keypair" {
  provider               = snowflake.accountadmin
  database               = snowflake_database.policies.name
  schema                 = "PUBLIC"
  name                   = "service_account_keypair"
  authentication_methods = ["KEYPAIR"]
  client_types           = ["DRIVERS", "SNOWSQL"]
  comment                = "Key-pair only authentication policy for most service accounts (PRD)"
}

resource "snowflake_authentication_policy" "legacy_service_password" {
  provider               = snowflake.accountadmin
  database               = snowflake_database.policies.name
  schema                 = "PUBLIC"
  name                   = "legacy_service_password"
  authentication_methods = ["PASSWORD"]
  client_types           = ["DRIVERS", "SNOWSQL"]
  comment                = "Password-only authentication policy for legacy service accounts (PRD)"
}

# Set odi_okta_only as the default account auth policy (fmt-clean)
resource "snowflake_account_authentication_policy_attachment" "default_policy" {
  count = var.okta_integration_name == null ? 0 : 1

  provider              = snowflake.accountadmin
  authentication_policy = snowflake_authentication_policy.odi_okta_only[0].fully_qualified_name
}
