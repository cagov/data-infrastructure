output "state" {
  description = "Resources from terraform state"
  value = {
    sql_server = {
      id   = azurerm_mssql_server.main.id
      name = azurerm_mssql_server.main.name
      fqdn = azurerm_mssql_server.main.fully_qualified_domain_name
    }

    sql_database = {
      id   = azurerm_mssql_database.main.id
      name = azurerm_mssql_database.main.name
    }

    service_principal = {
      application_id = azuread_application.sql_app.client_id
      object_id      = azuread_service_principal.sql_app.object_id
      display_name   = azuread_application.sql_app.display_name
    }

    admin_user = {
      user_principal_name = data.azuread_user.admin.user_principal_name
      object_id           = data.azuread_user.admin.object_id
    }

    # Connection details for Airflow/Data Factory
    connection = {
      host      = azurerm_mssql_server.main.fully_qualified_domain_name
      database  = azurerm_mssql_database.main.name
      port      = 1433
      client_id = azuread_application.sql_app.client_id
      tenant_id = data.azurerm_client_config.current.tenant_id
    }
  }

  sensitive = false
}
