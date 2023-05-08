# Terraform Snowflake remote state

This directory holds terraform configurations for DSE's primary
Snowflake account.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_snowflake"></a> [snowflake](#requirement\_snowflake) | ~> 0.61 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_elt"></a> [elt](#module\_elt) | ./modules/elt | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_airflow_public_key"></a> [airflow\_public\_key](#input\_airflow\_public\_key) | Public key for Airflow service user | `string` | n/a | yes |
| <a name="input_dbt_public_key"></a> [dbt\_public\_key](#input\_dbt\_public\_key) | Public key for dbt Cloud service user | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment suffix | `string` | n/a | yes |
| <a name="input_github_ci_public_key"></a> [github\_ci\_public\_key](#input\_github\_ci\_public\_key) | Public key for GitHub CI service user | `string` | n/a | yes |
| <a name="input_locator"></a> [locator](#input\_locator) | Snowflake account locator | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
