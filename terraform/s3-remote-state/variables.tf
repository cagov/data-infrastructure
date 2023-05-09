variable "owner" {
  description = "Owner of the resource"
  type        = string
  default     = "dse"
}

variable "project" {
  description = "Name of the project the resource is serving"
  type        = string
}

variable "environment" {
  description = "Deployment environment of the resource"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

locals {
  prefix = "${var.owner}-${var.project}-${var.environment}"
}
