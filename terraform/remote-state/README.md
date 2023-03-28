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
| <a name="input_name"></a> [name](#input\_name) | Prefix of name to append resource | `string` | `"dse-infra-dev"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region for AWS resources | `string` | `"us-west-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_state"></a> [state](#output\_state) | Resources from terraform-state |
<!-- END_TF_DOCS -->
