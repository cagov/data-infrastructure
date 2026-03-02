variable "owner" {
  description = "Owner of the resource"
  type        = string
  default     = "doe"
}

variable "project" {
  description = "Name of the project"
  type        = string
  default     = "opex"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "allowed_ip_addresses" {
  description = "IP addresses allowed to access SQL Database"
  type = list(object({
    name     = string
    start_ip = string
    end_ip   = string
  }))
  default = []
}

variable "allow_azure_services" {
  description = "Allow Azure services to access database"
  type        = bool
  default     = true
}

variable "admin_user_principal_name" {
  description = "Azure AD user principal name (email) for database admin"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  prefix = "${var.owner}-${var.project}-${var.environment}"
}
