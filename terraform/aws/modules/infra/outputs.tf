output "state" {
  description = "Resources from terraform-state"
  value = {
    repository_url       = aws_ecr_repository.default.repository_url
    scratch_bucket       = aws_s3_bucket.scratch.id
    mwaa_bucket          = aws_s3_bucket.mwaa.id
    github_actions_bot   = aws_iam_user.cd_bot.name
    batch_job_queue      = aws_batch_job_queue.default.name
    batch_job_definition = aws_batch_job_definition.default.name
  }
}
