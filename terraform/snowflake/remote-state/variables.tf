variable "owner" {
  description = "Owner of the resource"
  type        = string
  default     = "dse"
}

variable "project" {
  description = "Name of the project the resource is serving"
  type        = string
  default     = "snowflake"
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

locals {
  prefix = "${var.owner}-${var.project}-${var.environment}"
}
