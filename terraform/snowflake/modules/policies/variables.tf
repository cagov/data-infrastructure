variable "policies_database_name" {
  description = "Name of the database to store policies"
  type        = string
  default     = "POLICIES"
}

variable "okta_integration_name" {
  description = "Okta security integration name; if null, SAML policies/attachment are skipped"
  type        = string
  default     = "OKTAINTEGRATION"
}
