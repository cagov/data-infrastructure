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

variable "snowflake_storage_aws_iam_user_arn" {
  type = string
}

variable "snowflake_storage_aws_external_id" {
  type = string
}

variable "snowflake_snowpipe_sqs_queue" {
  type = string
}

locals {
  prefix = "${var.owner}-${var.project}-${var.environment}"
}
