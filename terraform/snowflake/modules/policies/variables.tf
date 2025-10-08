variable "environment" {
  description = "Environment suffix"
  type        = string
  default     = "PRD"
}

variable "okta_integration_name" {
  description = "The name of the Okta security integration. If null, the odi_okta_only and admin_okta_duo policies will not be created."
  type        = string
  default     = null
}

variable "policies_database_name" {
  description = "Name of the database to store policies"
  type        = string
  default     = "POLICIES"
}
