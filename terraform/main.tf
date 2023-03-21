##################################
#        Terraform Setup         #
##################################

terraform {
  backend "s3" {
  }

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
      Owner   = "CalData-DSE"
      Project = var.name
    }
  }
}

data "aws_caller_identity" "current" {}
