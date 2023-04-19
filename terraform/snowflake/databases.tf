resource "snowflake_database" "transform" {
  provider                    = snowflake.sysadmin
  name                        = "TRANSFORM"
  comment                     = "Transformation database"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "snowflake_database" "raw" {
  provider                    = snowflake.sysadmin
  name                        = "RAW"
  comment                     = "Raw database, intended for ingest of raw data from source systems prior to any modeling or transformation"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "snowflake_database" "analytics" {
  provider                    = snowflake.sysadmin
  name                        = "ANALYTICS"
  comment                     = "Analytics database for data consumers, holding analysis-ready data marts/models"
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}
