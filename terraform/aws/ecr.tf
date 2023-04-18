##################################
#       Container registry       #
##################################

resource "aws_ecr_repository" "default" {
  name                 = "${local.prefix}-${var.region}-default"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "default_ecr_policy_document" {
  # Policy from https://github.com/aws-actions/amazon-ecr-login#permissions
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.default.arn]
  }
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    # Why does this need *? https://github.com/aws-actions/amazon-ecr-login#ecr-private
    resources = ["*"]
  }
}

resource "aws_iam_policy" "default_ecr_policy" {
  name        = "${local.prefix}-${var.region}-default-ecr-push-policy"
  description = "Policy allowing pushing to the default ecr repository for ${local.prefix}"
  policy      = data.aws_iam_policy_document.default_ecr_policy_document.json
}
