terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

##################################
#          Data Sources          #
##################################

data "azurerm_client_config" "current" {}

data "azuread_user" "admin" {
  user_principal_name = var.admin_user_principal_name
}

##################################
#     Service Principal          #
##################################

# Service principal for programmatic access
# NOTE: Password/client secret is NOT created here to avoid storing in state
# Create the client secret manually after applying:
#
#   APP_ID=$(terraform output -json sqldb | jq -r '.service_principal.application_id')
#   az ad app credential reset --id $APP_ID --years 1

resource "azuread_application" "sql_app" {
  display_name = "${local.prefix}-sql-app"
  owners       = [data.azuread_user.admin.object_id]
}

resource "azuread_service_principal" "sql_app" {
  client_id = azuread_application.sql_app.client_id
  owners    = [data.azuread_user.admin.object_id]
}

##################################
#      SQL Server & Database     #
##################################

resource "azurerm_mssql_server" "main" {
  name                = "${local.prefix}-sqlserver"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "12.0"

  azuread_administrator {
    login_username              = data.azuread_user.admin.user_principal_name
    object_id                   = data.azuread_user.admin.object_id
    # Allow SQL authentication in addition to Azure AD: some data loaders
    # (including OpenFlow) don't support AD authentication, only SQL.
    azuread_authentication_only = false
  }

  minimum_tls_version           = "1.2"
  public_network_access_enabled = true

  tags = var.tags
}

resource "azurerm_mssql_database" "main" {
  name      = "${local.prefix}-db"
  server_id = azurerm_mssql_server.main.id

  sku_name                    = "GP_S_Gen5_1" # General Purpose Serverless, supports CDC
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60
  max_size_gb                 = 8
  zone_redundant              = false

  short_term_retention_policy {
    retention_days = 7
  }

  tags = var.tags
}

##################################
#       Firewall Rules           #
##################################

# Allow Azure services (Azure Data Factory, etc.)
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  count = var.allow_azure_services ? 1 : 0

  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Allow specific IP addresses
resource "azurerm_mssql_firewall_rule" "allowed_ips" {
  for_each = { for idx, rule in var.allowed_ip_addresses : rule.name => rule }

  name             = each.value.name
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = each.value.start_ip
  end_ip_address   = each.value.end_ip
}
