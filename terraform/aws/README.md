# CalData Terraform Infrastructure

This Terraform project sets up AWS infrastructure for the CalData Data Services and Engineering team.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 4.56.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.4.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.56.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.4.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_batch_compute_environment.default](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/batch_compute_environment) | resource |
| [aws_batch_job_definition.default](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/batch_job_definition) | resource |
| [aws_batch_job_queue.default](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/batch_job_queue) | resource |
| [aws_ecr_repository.default](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/ecr_repository) | resource |
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/eip) | resource |
| [aws_iam_group.aae](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_group) | resource |
| [aws_iam_group_membership.aae](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_group_membership) | resource |
| [aws_iam_group_policy_attachment.aae_dsa_project](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_group_policy_attachment) | resource |
| [aws_iam_policy.batch_submit_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.default_ecr_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.mwaa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.s3_dsa_project_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.s3_scratch_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.aws_batch_service_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role) | resource |
| [aws_iam_role.batch_job_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role) | resource |
| [aws_iam_role.mwaa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.aws_batch_service_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_role_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.mwaa_batch_submit_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.mwaa_execution_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_scratch_policy_role_attachment](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.cd_bot](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_user) | resource |
| [aws_iam_user.esa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.batch_cd_bot_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_user_policy_attachment) | resource |
| [aws_iam_user_policy_attachment.ecr_cd_bot_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_user_policy_attachment) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/internet_gateway) | resource |
| [aws_mwaa_environment.this](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/mwaa_environment) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.dsa_project](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.mwaa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.scratch](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.mwaa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.dsa_project](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.mwaa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.batch](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/security_group) | resource |
| [aws_security_group.mwaa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/vpc) | resource |
| [random_id.private_subnet](https://registry.terraform.io/providers/hashicorp/random/3.4.3/docs/resources/id) | resource |
| [random_id.public_subnet](https://registry.terraform.io/providers/hashicorp/random/3.4.3/docs/resources/id) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_batch_service_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.batch_submit_policy_document](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.default_ecr_policy_document](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.mwaa](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_dsa_project_policy_document](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_scratch_policy_document](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment of the resource | `string` | `"dev"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner of the resource | `string` | `"dse"` | no |
| <a name="input_project"></a> [project](#input\_project) | Name of the project the resource is serving | `string` | `"infra"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region for AWS resources | `string` | `"us-west-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_state"></a> [state](#output\_state) | Resources from terraform-state |
<!-- END_TF_DOCS -->
