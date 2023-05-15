##################################
#       DSE Infrastructure       #
##################################

# Overall policy for listing buckets in the console
data "aws_iam_policy_document" "s3_list_all_my_buckets" {
  statement {
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]
    resources = ["arn:aws:s3:::*"]
  }
}

resource "aws_iam_policy" "s3_list_all_my_buckets" {
  name        = "${local.prefix}-s3-list-all-my-buckets"
  description = "Policy allowing S3 bucket listing in the console"
  policy      = data.aws_iam_policy_document.s3_list_all_my_buckets.json
}

# Scratch bucket
resource "aws_s3_bucket" "scratch" {
  bucket = "${local.prefix}-${var.region}-scratch"
}

data "aws_iam_policy_document" "s3_scratch_policy_document" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.scratch.arn]
  }
  statement {
    actions = [
      "s3:ListBucket",
      "s3:*Object",
    ]
    resources = ["${aws_s3_bucket.scratch.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_scratch_policy" {
  name        = "${local.prefix}-${var.region}-s3-scratch-policy"
  description = "Policy allowing read/write for s3 scratch bucket"
  policy      = data.aws_iam_policy_document.s3_scratch_policy_document.json
}


# Snowpipe bucket
resource "aws_s3_bucket" "snowpipe_test" {
  bucket = "${local.prefix}-${var.region}-snowpipe-test"
}

data "aws_iam_policy_document" "snowpipe_test" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.snowpipe_test.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["*"]
    }

  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["${aws_s3_bucket.snowpipe_test.arn}/*"]
  }
}

resource "aws_iam_policy" "snowpipe_bucket_policy" {
  name        = "${local.prefix}-${var.region}-snowpipe-test-bucket-policy"
  description = "Policy allowing read/write for snowpipe-test bucket"
  policy      = data.aws_iam_policy_document.snowpipe_test.json
}

# MWAA bucket
resource "aws_s3_bucket" "mwaa" {
  bucket = "${local.prefix}-${var.region}-mwaa"
}

resource "aws_s3_bucket_versioning" "mwaa" {
  bucket = aws_s3_bucket.mwaa.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mwaa" {
  # required: https://docs.aws.amazon.com/mwaa/latest/userguide/mwaa-s3-bucket.html
  bucket                  = aws_s3_bucket.mwaa.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##################################
#     AAE DSA Project Buckets    #
##################################

locals {
  dsa_projects = [
    "water",
    "cdss",
    "hcd",
    "bppe",
    "cdtfa",
  ]
}

resource "aws_s3_bucket" "dsa_project" {
  for_each = toset(local.dsa_projects)
  bucket   = "aae-${each.key}-${var.environment}-${var.region}"
  tags = {
    Owner   = "aae"
    Project = each.key
  }
}

resource "aws_s3_bucket_versioning" "dsa_project" {
  for_each = toset(local.dsa_projects)
  bucket   = aws_s3_bucket.dsa_project[each.key].bucket
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "s3_dsa_project_policy_document" {
  for_each = toset(local.dsa_projects)
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetBucketAcl",
      "s3:GetBucketTagging",
    ]
    resources = [aws_s3_bucket.dsa_project[each.key].arn]
  }
  statement {
    actions = [
      "s3:ListBucket",
      "s3:*Object",
    ]
    resources = ["${aws_s3_bucket.dsa_project[each.key].arn}/*"]
  }
}

resource "aws_iam_policy" "s3_dsa_project_policy" {
  for_each    = toset(local.dsa_projects)
  name        = "aae-${each.key}-${var.environment}-s3-policy"
  description = "Policy allowing read/write for DSA ${each.key} bucket"
  policy      = data.aws_iam_policy_document.s3_dsa_project_policy_document[each.key].json
  tags = {
    Owner   = "aae"
    Project = each.key
  }
}
