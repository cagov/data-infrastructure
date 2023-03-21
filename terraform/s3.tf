##################################
#             S3                 #
##################################

# Scratch bucket
resource "aws_s3_bucket" "scratch" {
  bucket = "${var.name}-${var.region}-scratch"
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
  name        = "${var.name}-s3-scratch-policy"
  description = "Policy allowing read/write for s3 scratch bucket"
  policy      = data.aws_iam_policy_document.s3_scratch_policy_document.json
}


# MWAA bucket
resource "aws_s3_bucket" "mwaa" {
  bucket = "${var.name}-${var.region}-mwaa"
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
