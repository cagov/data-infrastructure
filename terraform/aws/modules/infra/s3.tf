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
#     DSE MDSA Project Buckets   #
##################################

resource "aws_s3_bucket" "dof_demographics_public" {
  bucket = "dof-demographics-${var.environment}-${var.region}-public"
  tags = {
    Owner   = "dof"
    Project = "demographics"
  }
}

resource "aws_s3_bucket_versioning" "dof_demographics_public" {
  bucket = aws_s3_bucket.dof_demographics_public.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "dof_demographics_public_read_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.dof_demographics_public.arn,
      "${aws_s3_bucket.dof_demographics_public.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "dof_demographics_public_read_access" {
  bucket = aws_s3_bucket.dof_demographics_public.id
  policy = data.aws_iam_policy_document.dof_demographics_public_read_access.json
}

data "aws_iam_policy_document" "dof_demographics_read_write_access" {
  statement {
    actions = [
      "s3:ListBucket"
    ]

    resources = [aws_s3_bucket.dof_demographics_public.arn]
  }
  statement {
    actions = [
      "s3:*Object",
    ]

    resources = [
      "${aws_s3_bucket.dof_demographics_public.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "dof_demographics_read_write_access" {
  name        = "${aws_s3_bucket.dof_demographics_public.id}-read-write"
  description = "Read/write access to the ${aws_s3_bucket.dof_demographics_public.id} bucket"
  policy      = data.aws_iam_policy_document.dof_demographics_read_write_access.json
}

resource "aws_s3_bucket_public_access_block" "dof_demographics_public" {
  bucket = aws_s3_bucket.dof_demographics_public.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
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
