##################################
#        Terraform Setup         #
##################################

terraform {
  backend "s3" {
  }

  # Note: when a package is added or updated, we have to update the lockfile in a
  # platform-independent way, cf. https://github.com/hashicorp/terraform/issues/28041
  # To update the lockfile run:
  #
  # terraform providers lock -platform=linux_amd64 -platform=darwin_amd64
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
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

data "aws_caller_identity" "current" {}
