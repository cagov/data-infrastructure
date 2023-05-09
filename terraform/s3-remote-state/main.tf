################################
#          Variables           #
################################

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

################################
#       Terraform setup        #
################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Owner       = var.owner
      Project     = var.project
      Environment = var.environment
    }
  }
}


################################
#        State backend         #
################################

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.prefix}-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${local.prefix}-terraform-state-lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

################################
# Outputs for a tfbackend file #
################################

output "bucket" {
  description = "State bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "key" {
  description = "State object key"
  value       = "${local.prefix}.tfstate"
}

output "region" {
  description = "AWS Region"
  value       = var.region
}

output "dynamodb_table" {
  description = "State lock"
  value       = aws_dynamodb_table.terraform_state_lock.name
}
