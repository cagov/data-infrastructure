output "logger_role_name" {
  description = "The name of the logger role."
  value       = snowflake_account_role.logger.name
}

output "logging_warehouse_name" {
  description = "The name of the logging warehouse."
  value       = module.logging.name
}
