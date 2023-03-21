##################################
#             S3                 #
##################################

resource "aws_s3_bucket" "scratch" {
  bucket = "${var.name}-scratch"
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
