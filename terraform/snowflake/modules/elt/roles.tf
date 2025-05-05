######################################
#       Functional Roles             #
######################################

# The loader persona is for tools like Airflow or Fivetran, which load
# raw data into Snowflake for later processing. It has read/write/control
# permissions in RAW.
resource "snowflake_account_role" "loader" {
  provider = snowflake.useradmin
  name     = "LOADER_${var.environment}"
  comment  = "Permissions to load data to the ${module.raw.name} database"
}

# The transformer persona is for in-warehouse data transformations. Most analytics
# engineers will use this role, as will dbt robot users. It has read/write/control
# permissions in ANALYTICS and TRANSFORM, as well as read permissions in RAW.
resource "snowflake_account_role" "transformer" {
  provider = snowflake.useradmin
  name     = "TRANSFORMER_${var.environment}"
  comment  = "Permissions to read data from the ${module.raw.name} database, and read/write to ${module.transform.name} and ${module.analytics.name}"
}

# The reporter persona is for BI tools to consume analysis-ready tables in the
# analytics databse. It has read permissions in ANALYTICS.
resource "snowflake_account_role" "reporter" {
  provider = snowflake.useradmin
  name     = "REPORTER_${var.environment}"
  comment  = "Permissions to read data from the ${module.analytics.name} database"
}

# The reader persona is for CI tools to be able to reflect on the databases.
# TODO: can we restrict the permissions for this role to just REFERENCES?
resource "snowflake_account_role" "reader" {
  provider = snowflake.useradmin
  name     = "READER_${var.environment}"
  comment  = "Permissions to read ${module.analytics.name}, ${module.transform.name}, and ${module.raw.name} for CI purposes"
}

# The logger role is for logging solutions like Sentinel to introspect
# things like usage and access.
resource "snowflake_account_role" "logger" {
  provider = snowflake.useradmin
  name     = "LOGGER_${var.environment}"
  comment  = "Permissions to read the SNOWFLAKE metadatabase for logging purposes"
}

# Adding streamlit role - only for analytics database
resource "snowflake_account_role" "streamlit_analytics" {
  provider = snowflake.useradmin
  name     = "${module.analytics.name}_STREAMLIT"
  comment  = "Permissions to create Streamlit applications and stages in the ${module.analytics.name} database for the ${var.environment} environment."
}

######################################
#            Role Grants             #
######################################

# Grant our roles to the SYSADMIN user, per best practices:
# https:#docs.snowflake.com/en/user-guide/security-access-control-considerations#aligning-object-access-with-business-functions
# This allows SYSADMIN to make additional grants of database objects to these roles.

resource "snowflake_grant_account_role" "loader_to_sysadmin" {
  provider         = snowflake.useradmin
  role_name        = snowflake_account_role.loader.name
  parent_role_name = "SYSADMIN"
}

resource "snowflake_grant_account_role" "transformer_to_sysadmin" {
  provider         = snowflake.useradmin
  role_name        = snowflake_account_role.transformer.name
  parent_role_name = "SYSADMIN"
}

resource "snowflake_grant_account_role" "reporter_to_sysadmin" {
  provider         = snowflake.useradmin
  role_name        = snowflake_account_role.reporter.name
  parent_role_name = "SYSADMIN"
}

resource "snowflake_grant_account_role" "reader_to_sysadmin" {
  provider         = snowflake.useradmin
  role_name        = snowflake_account_role.reader.name
  parent_role_name = "SYSADMIN"
}

# NOTE: logger has elevated privileges, so it is assigned
# directly to accountadmin
resource "snowflake_grant_account_role" "logger_to_accountadmin" {
  provider         = snowflake.accountadmin
  role_name        = snowflake_account_role.logger.name
  parent_role_name = "ACCOUNTADMIN"
}

# Loader has RWC privileges in RAW
resource "snowflake_grant_account_role" "raw_rwc_to_loader" {
  provider         = snowflake.useradmin
  role_name        = "${module.raw.name}_READWRITECONTROL"
  parent_role_name = snowflake_account_role.loader.name
}

# Reporter has read privileges in ANALYTICS
resource "snowflake_grant_account_role" "analytics_r_to_reporter" {
  provider         = snowflake.useradmin
  role_name        = "${module.analytics.name}_READ"
  parent_role_name = snowflake_account_role.reporter.name
}

# Transformer has RWC privileges in TRANSFORM
resource "snowflake_grant_account_role" "transform_rwc_to_transformer" {
  provider         = snowflake.useradmin
  role_name        = "${module.transform.name}_READWRITECONTROL"
  parent_role_name = snowflake_account_role.transformer.name
}

# Transformer has RWC privileges in ANALYTICS
resource "snowflake_grant_account_role" "analytics_rwc_to_transformer" {
  provider         = snowflake.useradmin
  role_name        = "${module.analytics.name}_READWRITECONTROL"
  parent_role_name = snowflake_account_role.transformer.name
}

# Transformer has read permissions in RAW
resource "snowflake_grant_account_role" "raw_r_to_transformer" {
  provider         = snowflake.useradmin
  role_name        = "${module.raw.name}_READ"
  parent_role_name = snowflake_account_role.transformer.name
}

# Transformer can use the TRANSFORMING warehouse
resource "snowflake_grant_account_role" "transforming_to_transformer" {
  provider         = snowflake.useradmin
  for_each         = toset(keys(local.sizes))
  role_name        = module.transforming[each.key].access_role_name
  parent_role_name = snowflake_account_role.transformer.name
}

# Reporter can use the REPORTING warehouse
resource "snowflake_grant_account_role" "reporting_to_reporter" {
  provider         = snowflake.useradmin
  for_each         = toset(keys(local.sizes))
  role_name        = module.reporting[each.key].access_role_name
  parent_role_name = snowflake_account_role.reporter.name
}

# Loader can use the LOADING warehouse
resource "snowflake_grant_account_role" "loading_to_loader" {
  provider         = snowflake.useradmin
  for_each         = toset(keys(local.sizes))
  role_name        = module.loading[each.key].access_role_name
  parent_role_name = snowflake_account_role.loader.name
}

# Reader has read permissions in RAW
resource "snowflake_grant_account_role" "raw_r_to_reader" {
  provider         = snowflake.useradmin
  role_name        = "${module.raw.name}_READ"
  parent_role_name = snowflake_account_role.reader.name
}

# Reader has read permissions in TRANSFORM
resource "snowflake_grant_account_role" "transform_r_to_reader" {
  provider         = snowflake.useradmin
  role_name        = "${module.transform.name}_READ"
  parent_role_name = snowflake_account_role.reader.name
}

# Reader has read permissions in ANALYTICS
resource "snowflake_grant_account_role" "analytics_r_to_reader" {
  provider         = snowflake.useradmin
  role_name        = "${module.analytics.name}_READ"
  parent_role_name = snowflake_account_role.reader.name
}

# Reader can use the REPORTING warehouse
resource "snowflake_grant_account_role" "reporting_to_reader" {
  provider         = snowflake.useradmin
  for_each         = toset(keys(local.sizes))
  role_name        = module.reporting[each.key].access_role_name
  parent_role_name = snowflake_account_role.reader.name
}

# Logger can use the LOGGING warehouse
resource "snowflake_grant_account_role" "logging_to_logger" {
  provider         = snowflake.useradmin
  role_name        = module.logging.access_role_name
  parent_role_name = snowflake_account_role.logger.name
}

######################################
#          Privilege Grants          #
######################################

# Imported privileges for logging
resource "snowflake_grant_privileges_to_account_role" "imported_privileges_to_logger" {
  provider          = snowflake.accountadmin
  account_role_name = snowflake_account_role.logger.name
  privileges        = ["IMPORTED PRIVILEGES"]
  on_account_object {
    object_type = "DATABASE"
    object_name = "SNOWFLAKE"
  }
}

##############################################################
# Grant TRANSFORM_READ role to ANALYTICS_READWRITECONTROL role
# This is a workaround for sharing views
# More backgorund information related to this is found
# here - https://github.com/cagov/data-infrastructure/issues/274
##############################################################

resource "snowflake_grant_account_role" "transform_read_to_analytics_rwc" {
  provider         = snowflake.useradmin
  role_name        = "${module.transform.name}_READ"
  parent_role_name = "${module.analytics.name}_READWRITECONTROL"
}

# Grant the Streamlit roles to the Reporter role in the current environment
# The cross-environment grant of the ${module.raw.name}_${var.environment}_STREAMLIT role
# to the REPORTER_DEV role will handled outside of this Terraform configuration.
# via manual SQL execution
resource "snowflake_grant_account_role" "streamlit_analytics_to_reporter" {
  provider         = snowflake.useradmin
  role_name        = snowflake_account_role.streamlit_analytics.name
  parent_role_name = snowflake_account_role.reporter.name
}

resource "snowflake_grant_privileges_to_account_role" "streamlit_database_privileges" {
  account_role_name = "${module.analytics.name}_STREAMLIT"
  privileges        = ["CREATE STAGE"]
  on_account_object {
    object_name = "ANALYTICS_PRD"
    object_type = "DATABASE"
  }
}

resource "snowflake_grant_privileges_to_account_role" "streamlit_account_privileges" {
  account_role_name = "${module.analytics.name}_STREAMLIT"
  privileges        = ["CREATE STREAMLIT"]
  on_account        = true
}
