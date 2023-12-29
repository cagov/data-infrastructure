##################################
#          IAM Policies          #
##################################

# Adapted from https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_aws_my-sec-creds-self-manage.html
data "aws_iam_policy_document" "self_manage_credentials" {
  statement {
    sid    = "AllowViewAccountInfo"
    effect = "Allow"
    actions = [
      "iam:GetAccountPasswordPolicy",
      "iam:GetAccountSummary",
      "iam:ListVirtualMFADevices",
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowManageOwnPasswords"
    effect = "Allow"
    actions = [
      "iam:ChangePassword",
      "iam:GetUser",
      "iam:CreateLoginProfile",
      "iam:DeleteLoginProfile",
      "iam:GetLoginProfile",
      "iam:UpdateLoginProfile",
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnAccessKeys"
    effect = "Allow"
    actions = [
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:ListAccessKeys",
      "iam:UpdateAccessKey",
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid    = "AllowManageOwnVirtualMFADevice"
    effect = "Allow"
    actions = [
      "iam:CreateVirtualMFADevice"
    ]
    resources = ["arn:aws:iam::*:mfa/*"]
  }
  statement {
    sid    = "AllowManageOwnUserMFA"
    effect = "Allow"
    actions = [
      "iam:DeactivateMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ResyncMFADevice"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
}

resource "aws_iam_policy" "self_manage_credentials" {
  name        = "${local.prefix}-self-manage-credentials-policy"
  description = "Allow a user to manage their own credentials"
  policy      = data.aws_iam_policy_document.self_manage_credentials.json
}

data "aws_iam_policy_document" "access_snowflake_loader" {
  for_each = toset(local.jobs)
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      data.aws_secretsmanager_secret.snowflake_loader_secret[each.key].arn
    ]
  }
}

resource "aws_iam_policy" "access_snowflake_loader" {
  for_each    = toset(local.jobs)
  name        = "${local.prefix}-access-snowflake-loader-${each.key}"
  description = "Allow a user/role to access Snowflake loader role in SecretsManager for the ${each.key} secret"
  policy      = data.aws_iam_policy_document.access_snowflake_loader[each.key].json
}

##################################
#        IAM Service Users       #
##################################

# NOTE: in general, policies and roles are defined close to the resources
# they support.

# CD bot for GitHub actions
resource "aws_iam_user" "cd_bot" {
  name = "${local.prefix}-cd-bot"
}

resource "aws_iam_user_policy_attachment" "ecr_cd_bot_policy_attachment" {
  user       = aws_iam_user.cd_bot.name
  policy_arn = aws_iam_policy.default_ecr_policy.arn
}

resource "aws_iam_user_policy_attachment" "batch_cd_bot_policy_attachment" {
  user       = aws_iam_user.cd_bot.name
  policy_arn = aws_iam_policy.batch_submit_policy.arn
}

##################################
#         IAM Human Users        #
##################################

resource "aws_iam_user" "arman" {
  name = "ArmanMadani"
}

resource "aws_iam_user" "esa" {
  name = "EsaEslami"
}

resource "aws_iam_user" "kim" {
  name = "KimHicks"
}

resource "aws_iam_user" "monica" {
  name = "MonicaBobra"
}

resource "aws_iam_user" "rocio" {
  name = "RocioMora"
}

##################################
#         IAM User Groups        #
##################################

resource "aws_iam_group" "aae" {
  name = "odi-advanced-analytics-${var.environment}"
}

resource "aws_iam_group_policy_attachment" "aae_dsa_project" {
  for_each   = toset(local.dsa_projects)
  group      = aws_iam_group.aae.name
  policy_arn = aws_iam_policy.s3_dsa_project_policy[each.key].arn
}

resource "aws_iam_group_policy_attachment" "aae_list_all_my_buckets" {
  group      = aws_iam_group.aae.name
  policy_arn = aws_iam_policy.s3_list_all_my_buckets.arn
}

resource "aws_iam_group_policy_attachment" "aae_self_manage_creentials" {
  group      = aws_iam_group.aae.name
  policy_arn = aws_iam_policy.self_manage_credentials.arn
}

resource "aws_iam_group_membership" "aae" {
  name  = "${aws_iam_group.aae.name}-membership"
  group = aws_iam_group.aae.name
  users = [
    aws_iam_user.arman.name,
    aws_iam_user.esa.name,
    aws_iam_user.kim.name,
    aws_iam_user.monica.name,
    aws_iam_user.rocio.name,
  ]
}
