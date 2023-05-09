output "bucket" {
  description = "State bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "key" {
  description = "State object key"
  value       = "${local.prefix}.tfstate"
}

output "region" {
  description = "AWS Region"
  value       = var.region
}

output "dynamodb_table" {
  description = "State lock"
  value       = aws_dynamodb_table.terraform_state_lock.name
}
