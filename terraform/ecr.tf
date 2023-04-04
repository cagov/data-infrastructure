##################################
#       Container registry       #
##################################

resource "aws_ecr_repository" "main_ecr" {
  name                 = "${local.prefix}-ecr-${var.region}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "main_ecr_policy_document" {
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
    resources = [aws_ecr_repository.main_ecr.arn]
  }
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    # Why does this need *? https://github.com/aws-actions/amazon-ecr-login#ecr-private
    resources = ["*"]
  }
}

resource "aws_iam_policy" "main_ecr_policy" {
  name        = "${local.prefix}-ecr-push-policy"
  description = "Policy allowing pushing to the main ecr repository for ${local.prefix}"
  policy      = data.aws_iam_policy_document.main_ecr_policy_document.json
}
