output "state" {
  description = "Resources from terraform-state"
  value = {
    repository_url = aws_ecr_repository.main_ecr.repository_url
  }
}
