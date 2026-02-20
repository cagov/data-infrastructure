terraform {
  required_version = ">= 1.0"

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

  backend "s3" {
    # Configuration from dse-sqldb-dev.tfbackend
  }
}

variable "admin_user_email" {
  description = "Email address (User Principal Name) of Azure AD admin for SQL Database"
  type        = string
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses allowed to access SQL Database"
  type        = list(string)
  default     = []
}

locals {
  owner       = "doe"
  environment = "dev"
  project     = "opex"
  location    = "westus2"
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {
  # Uses same Azure CLI authentication as azurerm
}

# Shared resource group for opex resources
resource "azurerm_resource_group" "opex" {
  name     = "${local.owner}-${local.project}-${local.environment}-rg"
  location = local.location

  tags = {
    Owner       = local.owner
    Project     = local.project
    Environment = local.environment
  }
}

module "sqldb" {
  source = "../../modules/sqldb"

  owner               = local.owner
  environment         = local.environment
  project             = "sqldb"
  resource_group_name = azurerm_resource_group.opex.name
  location            = azurerm_resource_group.opex.location

  admin_user_principal_name = var.admin_user_email

  # Convert simple IP list to module's expected format
  allowed_ip_addresses = [
    for idx, ip in var.allowed_ip_addresses : {
      name     = "allowed-ip-${idx}"
      start_ip = ip
      end_ip   = ip
    }
  ]
  allow_azure_services = true

  tags = {
    Owner       = local.owner
    Project     = local.project
    Environment = local.environment
  }
}

output "resource_group" {
  description = "Shared resource group for opex resources"
  value = {
    name     = azurerm_resource_group.opex.name
    location = azurerm_resource_group.opex.location
  }
}

output "sqldb" {
  value     = module.sqldb.state
  sensitive = false
}
