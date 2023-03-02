output "state" {
  description = "Resources from terraform-state"
  value = {
    repository_url = aws_ecr_repository.main-ecr.repository_url
  }
}
