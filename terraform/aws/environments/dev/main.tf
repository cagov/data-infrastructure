##################################
#        Terraform Setup         #
##################################

terraform {
  required_version = ">= 1.0"

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

  backend "s3" {
  }
}

locals {
  owner       = "dse"
  environment = "dev"
  project     = "infra"
  region      = "us-west-2"
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

############################
#      Infrastructure      #
############################

module "infra" {
  source = "../../modules/infra"

  owner                   = local.owner
  environment             = local.environment
  project                 = local.project
  snowflake_loader_secret = "arn:aws:secretsmanager:us-west-2:676096391788:secret:dse-snowflake-dev-us-west-2-loader-q1kChm"
}
