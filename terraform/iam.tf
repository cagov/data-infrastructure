##################################
#    IAM Roles, Groups, Users    #
##################################

# NOTE: in general, policies and roles are defined close to the resources
# they support.

# CD bot for GitHub actions
resource "aws_iam_user" "cd_bot" {
  name = "${local.prefix}-cd-bot"
}

resource "aws_iam_user_policy_attachment" "ecr_cd_bot_policy_attachment" {
  user       = aws_iam_user.cd_bot.name
  policy_arn = aws_iam_policy.main_ecr_policy.arn
}

resource "aws_iam_user_policy_attachment" "batch_cd_bot_policy_attachment" {
  user       = aws_iam_user.cd_bot.name
  policy_arn = aws_iam_policy.batch_submit_policy.arn
}
