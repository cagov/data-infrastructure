variable "owner" {
  description = "Owner of the resource"
  type        = string
  default     = "dse"
}

variable "project" {
  description = "Name of the project the resource is serving"
  type        = string
  default     = "infra"
}

variable "environment" {
  description = "Deployment environment of the resource"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Region for AWS resources"
  type        = string
  default     = "us-west-2"
}

variable "snowflake_loader_secret" {
  description = "ARN for SecretsManager login info to Snowflake with loader role"
  type        = object({ test = string, latest = string })
  default     = null
}

locals {
  prefix = "${var.owner}-${var.project}-${var.environment}"
}
