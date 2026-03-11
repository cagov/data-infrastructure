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

variable "enable_rds" {
  description = "Whether to enable RDS SQL Server instance"
  type        = bool
  default     = false
}

variable "bastion_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the bastion (e.g. Fivetran IP ranges, office IPs)"
  type        = list(string)
  default     = []
}

variable "bastion_authorized_keys" {
  description = "SSH public keys authorized to access the bastion (one per external system or developer)"
  type        = list(string)
  default     = []
}

variable "privatelink_allowed_principals" {
  description = "AWS principal ARNs allowed to connect via PrivateLink (e.g. Fivetran, Snowflake account ARNs in the form arn:aws:iam::<account-id>:root)"
  type        = list(string)
  default     = []
}

locals {
  prefix = "${var.owner}-${var.project}-${var.environment}"
}
