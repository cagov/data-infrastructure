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
