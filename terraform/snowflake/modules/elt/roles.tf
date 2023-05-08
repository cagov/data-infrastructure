######################################
#       Functional Roles             #
######################################

# The loader persona is for tools like Airflow or Fivetran, which load
# raw data into Snowflake for later processing. It has read/write/control
# permissions in RAW.
resource "snowflake_role" "loader" {
  provider = snowflake.useradmin
  name     = "LOADER_${var.environment}"
  comment  = "Permissions to load data to the ${module.raw.name} database"
}

# The transformer persona is for in-warehouse data transformations. Most analytics
# engineers will use this role, as will dbt robot users. It has read/write/control
# permissions in ANALYTICS and TRANSFORM, as well as read permissions in RAW.
resource "snowflake_role" "transformer" {
  provider = snowflake.useradmin
  name     = "TRANSFORMER_${var.environment}"
  comment  = "Permissions to read data from the ${module.raw.name} database, and read/write to ${module.transform.name} and ${module.analytics.name}"
}

# The reporter persona is for BI tools to consume analysis-ready tables in the
# analytics databse. It has read permissions in ANALYTICS.
resource "snowflake_role" "reporter" {
  provider = snowflake.useradmin
  name     = "REPORTER_${var.environment}"
  comment  = "Permissions to read data from the ${module.analytics.name} database"
}

# The reader persona is for CI tools to be able to reflect on the databases.
# TODO: can we restrict the permissions for this role to just REFERENCES?
resource "snowflake_role" "reader" {
  provider = snowflake.useradmin
  name     = "READER_${var.environment}"
  comment  = "Permissions to read ${module.analytics.name}, ${module.transform.name}, and ${module.raw.name} for CI purposes"
}


######################################
#            Role Grants             #
######################################

# Grant our roles to the SYSADMIN user, per best practices:
# https:#docs.snowflake.com/en/user-guide/security-access-control-considerations#aligning-object-access-with-business-functions
# This allows SYSADMIN to make additional grants of database objects to these roles.

resource "snowflake_role_grants" "loader_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.loader.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

resource "snowflake_role_grants" "transformer_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.transformer.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

resource "snowflake_role_grants" "reporter_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.reporter.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

resource "snowflake_role_grants" "reader_to_sysadmin" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.reader.name
  enable_multiple_grants = true
  roles                  = ["SYSADMIN"]
}

# Loader has RWC privileges in RAW
resource "snowflake_role_grants" "raw_rwc_to_loader" {
  provider               = snowflake.useradmin
  role_name              = "${module.raw.name}_READWRITECONTROL"
  enable_multiple_grants = true
  roles                  = [snowflake_role.loader.name]
}

# Reporter has read privileges in ANALYTICS
resource "snowflake_role_grants" "analytics_r_to_reporter" {
  provider               = snowflake.useradmin
  role_name              = "${module.analytics.name}_READ"
  enable_multiple_grants = true
  roles                  = [snowflake_role.reporter.name]
}

# Transformer has RWC privileges in TRANSFORM
resource "snowflake_role_grants" "transform_rwc_to_transformer" {
  provider               = snowflake.useradmin
  role_name              = "${module.transform.name}_READWRITECONTROL"
  enable_multiple_grants = true
  roles                  = [snowflake_role.transformer.name]
}

# Transformer has RWC privileges in ANALYTICS
resource "snowflake_role_grants" "analytics_rwc_to_transformer" {
  provider               = snowflake.useradmin
  role_name              = "${module.analytics.name}_READWRITECONTROL"
  enable_multiple_grants = true
  roles                  = [snowflake_role.transformer.name]
}

# Transformer has read permissions in RAW
resource "snowflake_role_grants" "raw_r_to_transformer" {
  provider               = snowflake.useradmin
  role_name              = "${module.raw.name}_READ"
  enable_multiple_grants = true
  roles                  = [snowflake_role.transformer.name]
}

# Transformer can use the TRANSFORMING warehouse
resource "snowflake_role_grants" "transforming_to_transformer" {
  provider               = snowflake.useradmin
  role_name              = module.transforming.access_role_name
  enable_multiple_grants = true
  roles                  = [snowflake_role.transformer.name]
}

# Reporter can use the REPORTING warehouse
resource "snowflake_role_grants" "reporting_to_reporter" {
  provider               = snowflake.useradmin
  role_name              = module.reporting.access_role_name
  enable_multiple_grants = true
  roles                  = [snowflake_role.reporter.name]
}

# Loader can use the LOADING warehouse
resource "snowflake_role_grants" "loading_to_loader" {
  provider               = snowflake.useradmin
  role_name              = module.loading.access_role_name
  enable_multiple_grants = true
  roles                  = [snowflake_role.loader.name]
}

# Reader has read permissions in RAW
resource "snowflake_role_grants" "raw_r_to_reader" {
  provider               = snowflake.useradmin
  role_name              = "${module.raw.name}_READ"
  enable_multiple_grants = true
  roles                  = [snowflake_role.reader.name]
}

# Reader has read permissions in TRANSFORM
resource "snowflake_role_grants" "transform_r_to_reader" {
  provider               = snowflake.useradmin
  role_name              = "${module.transform.name}_READ"
  enable_multiple_grants = true
  roles                  = [snowflake_role.reader.name]
}

# Reader has read permissions in ANALYTICS
resource "snowflake_role_grants" "analytics_r_to_reader" {
  provider               = snowflake.useradmin
  role_name              = "${module.analytics.name}_READ"
  enable_multiple_grants = true
  roles                  = [snowflake_role.reader.name]
}

# Reader can use the REPORTING warehouse
resource "snowflake_role_grants" "reporting_to_reader" {
  provider               = snowflake.useradmin
  role_name              = module.reporting.access_role_name
  enable_multiple_grants = true
  roles                  = [snowflake_role.reader.name]
}
