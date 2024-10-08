output "access_role_name" {
  description = "Warehouse access_role"
  value       = snowflake_role.this.name
}

output "name" {
  description = "Warehouse name"
  value       = snowflake_warehouse.this.name
}
