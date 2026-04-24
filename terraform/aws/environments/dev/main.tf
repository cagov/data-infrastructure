##################################
#        Terraform Setup         #
##################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.0"
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

  owner       = local.owner
  environment = local.environment
  project     = local.project
  snowflake_loader_secret = {
    test   = "dse-snowflake-dev-us-west-2-loader"
    latest = "dse-snowflake-prd-us-west-2-loader"
  }

  # RDS SQL Server configuration
  enable_rds = true
  bastion_authorized_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfK0wv8JVqrD9Y3VabRAOgqdIj9nZ1hqzmaiJNCW8Tfy0DRM6U6AomsPX25DaZm+TIwpMj7ymasaZ7G+dvEKeisCaKwMDqpZrv4S8PplpcV4fCbmtT7Q5CNHdhspkjyOf7Ee/rYNowicDUsDBxYTDNuucXJKwCgu7hMR43IPfYifhq9JqOrHtSZ1smQ3+8Hec0TybtztgJ5BC7xKYpphUodwNwPTK8gF6p5Dyroe+WkzyIHgmOy2d/wY7D/K/FOV2YinxIvRoo2L0DHExNnAPBzGFYfE4ZfNusbLPulvMHByNalCAwN14qJEZ88MY7COmOxzpFGE/aCJPIG/wAzvC1EE76GEGARjWgasI7ISopRHgLVajsEjHpH/gVrPckET6DGd+6J4amrbvsXaF1/+5NcZrW8CocMaMIgjrtweBbVUU8GrsF3WtL5SnGmr4d54e9EsnuagRVFHGA3ij6ie3U84T8fatqOQ6gOBHW+a6kxvgL4jQ+jiB0e8DjZD43sLWNeNofkvEx38ahqkYz136Q5H8yf0YGfr7xCCgZkrh0zZb9GBlakEHqiJIIRde33ab3LIQPkn+C0VDQFRZ6n2sCwN/G6qt+BVfHwUzGZo4JHTGDyDqqBBdGAipcAFwLZgnkNqfSaymO+V2SZEyBJ1i/ME4SHiB7wV+Cw4D14IwqfQ== fivetran user key",
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWI/uDNjGkZqM9PC8znGUDrBQPQwlRi2TxKaoUh2MsZcnvH5YEfqCQg/ZwMN3Ce2uhgzm9ALAQaEBKkhpaDiDw7FUt1K04gD1AbBMGtZqcd0AXiFNFEMddlERjZCh5lR9XESe3gln2e6SHJ/WKgORCdp6p7LWjWs9hoowxMeLP18CJYsbwSRYxe7cVRrxAhhRfNgiD2YjXbkpvif/At5kW7Ef1iVVv4nxsYCfjNQiZC0+np/roXLDfn1peSm6Kpy3CZgfuCDlxmcZGL8pvYfiXJ5wyUey7CTDyP0uhalwYr+272YEP6aP/Td1dQhu6f82wgsfhYMnMe08u+bmBivGJqIsKr0OkLXIvcOFY+WsIXsrQ87b1Yzem9ojmRoRv6I6Tf8LAc18dpk1WZ0wg5O5PtEKC+aSQ9haBjB3lGwOKwo3+pgZvuEzU3RbchWwPHxi4l02uklhVOHkEm8ek3UzL4UI6AAW8SOqbGQlsmlPqrn3yaY+CVBBz3Fnh5864VcU= estuary"
  ]
  bastion_allowed_ssh_cidrs = [
    # Fivetran GCP us-east-4 (default processing region)
    "35.234.176.144/29",
    # Estuary IP ranges
    "34.213.10.188/32",
    "52.34.175.198/32"
  ]
  privatelink_allowed_principals = [
    "arn:aws:iam::024848475617:root",  # Snowflake
    "arn:aws:iam::834469178297:root",  # Fivetran
  ]

}

output "infra" {
  value = module.infra.state
}
