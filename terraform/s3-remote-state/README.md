# Terraform S3 remote state

This Terraform module is intended to bootstrap remote state for the main terraform
project in the parent directory.

It uses the [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3),
which stores the state in an S3 bucket and uses a DynamoDB table for locking.

Ideally, this should only need to be set up once per project:

```bash
terraform apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 4.56.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.56.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.terraform_state_lock](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/dynamodb_table) | resource |
| [aws_s3_bucket.terraform_state](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_versioning.terraform_state](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment of the resource | `string` | n/a | yes |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner of the resource | `string` | `"dse"` | no |
| <a name="input_project"></a> [project](#input\_project) | Name of the project the resource is serving | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | `"us-west-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket"></a> [bucket](#output\_bucket) | State bucket |
| <a name="output_dynamodb_table"></a> [dynamodb\_table](#output\_dynamodb\_table) | State lock |
| <a name="output_key"></a> [key](#output\_key) | State object key |
| <a name="output_region"></a> [region](#output\_region) | AWS Region |
<!-- END_TF_DOCS -->
