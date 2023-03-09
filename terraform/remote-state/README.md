# Terraform S3 remote state

This Terraform module is intended to bootstrap remote state for the main terraform
project in the parent directory.

It uses the [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3),
which stores the state in an S3 bucket and uses a DynamoDB table for locking.

Ideally, this should only need to be set up once per project:

```bash
terraform apply
```
