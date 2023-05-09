# Setup
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
  region = local.region

  default_tags {
    tags = {
      Owner       = local.owner
      Project     = local.project
      Environment = local.environment
    }
  }
}

# Pull in the remote state module
module "remote_state" {
  source = "../../../../s3-remote-state"

  owner       = local.owner
  environment = local.environment
  project     = local.project
  region      = local.region
}


# Configuration
locals {
  owner       = "dse"
  environment = "dev"
  project     = "snowflake"
  region      = "us-west-2"
}



# Outputs fit for a .tfbackend file
output "bucket" {
  value = module.remote_state.bucket
}
output "key" {
  value = module.remote_state.key
}
output "region" {
  value = module.remote_state.region
}
output "dynamodb_table" {
  value = module.remote_state.dynamodb_table
}
