resource "snowflake_warehouse" "loading" {
  name                = "LOADING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for loading data to Snowflake from ELT/ETL tools"
  warehouse_size      = "x-small"
}

resource "snowflake_warehouse" "transforming" {
  name                = "TRANSFORMING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for transforming data. Analytics engineers and automated transformation tools should use this warehouse"
  warehouse_size      = "x-small"
}

resource "snowflake_warehouse" "reporting" {
  name                = "REPORTING"
  provider            = snowflake.sysadmin
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "Primary warehouse for reporting. End-users and BI tools should use this warehouse"
  warehouse_size      = "x-small"
}
