# CalData Terraform Infrastructure

This Terraform project

## Setup

### Installation

This project requires Terraform to run.
You might use any of a number of different package managers to install it depending on your system.

For Macs, you can use `brew`:

```bash
brew install terraform
```

Anaconda users on any archictecture should be able to use `conda` or `mamba`:

```bash
conda install -c conda-forge terraform
```

We also use `tflint` for linting, and `terraform-docs` to help with documentation of resources.
These can be installed in the same manner, e.g.:

```bash
conda install -c conda-forge tflint go-terraform-docs
```

There are a number of pre-commit checks that run on committing as well as in CI.
To install the checks, run the following from the repository root:

```bash
pre-commit install
```

You can manually run the pre-commit checks using

```bash
pre-commit run --all-files
```

### Bootstrapping remote state

When deploying a new version of your infrastrucutre, Terraform diffs the current state
against what you have specified in your infrastructure-as-code.
The current state is tracked in a JSON document,
which can be stored in any of a number of locations (including local files).

This project stores remote state using the [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3).
Before you can stand up the main infrastructure, you must first prep the remote state backend:

```bash
cd remote-state
terraform init
terraform apply
```

With the remote state infrastructure deployed, you should be able to initialize the main project.
From this directory, run:

```bash
terraform init -backend-config=./remote-state/dse-infra-dev.tfbackend
```

## Deploying Infrastructure

When you are ready to deploy a new version of the infrastructure, run

```bash
terraform apply
```

This will output the changes to the infrastructure that will be made, and prompt you for confirmation.


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
| [aws_batch_compute_environment.batch_env](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/batch_compute_environment) | resource |
| [aws_batch_job_definition.batch_job_def](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/batch_job_definition) | resource |
| [aws_batch_job_queue.batch_queue](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/batch_job_queue) | resource |
| [aws_ecr_repository.main_ecr](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/ecr_repository) | resource |
| [aws_iam_policy.batch_submit_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.main_ecr_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.s3_scratch_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.aws_batch_service_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role) | resource |
| [aws_iam_role.batch_job_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.aws_batch_service_role](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_role_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_scratch_policy_role_attachment](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.cd_bot](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.batch_cd_bot_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_user_policy_attachment) | resource |
| [aws_iam_user_policy_attachment.ecr_cd_bot_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/iam_user_policy_attachment) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/internet_gateway) | resource |
| [aws_route.public](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/route) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/route_table) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.scratch](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/s3_bucket) | resource |
| [aws_security_group.sg](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/security_group) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/resources/vpc) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_batch_service_policy](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.batch_submit_policy_document](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.main_ecr_policy_document](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_scratch_policy_document](https://registry.terraform.io/providers/hashicorp/aws/4.56.0/docs/data-sources/iam_policy_document) | data source |

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
