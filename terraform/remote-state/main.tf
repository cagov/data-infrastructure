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
      Owner   = "CalData-DSE"
      Project = var.name
    }
  }
}

resource "aws_s3_bucket" "terraform-state" {
  bucket = "${var.name}-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform-state-lock" {
  name           = "${var.name}-terraform-state-lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
