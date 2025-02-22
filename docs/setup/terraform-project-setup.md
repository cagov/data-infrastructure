# Deploy project infrastructure using Terraform

We will create two separate deployments of the project infrastructure,
one for development, and one for production.
In some places we will refer to project name and owner as `<project>` and `<owner>`, respectively,
following our [naming conventions](../learning/naming-conventions.md).
You should substitute the appropriate names there.

## Create the dev configuration

1. Ensure that your environment has environment variables set for
    `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY_PATH`, and `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`.
    Make sure you *don't* have any other `SNOWFLAKE_*` variables set,
    as they can interfere with authentication.
1. In the new git repository, create a directory to hold the development Terraform configuration:
    ```bash
    mkdir -p terraform/environments/dev/
    ```
    The location of this directory is by convention, and subject to change.
1. Copy the terraform configuration from
    [here](https://github.com/cagov/data-infrastructure/blob/main/terraform/snowflake/environments/dev/main.tf)
    to your `dev` directory.
1. In the "elt" module of `main.tf`, change the `source` parameter to point to
    `"github.com/cagov/data-infrastructure.git//terraform/snowflake/modules/elt?ref=<ref>"`
    where `<ref>` is the short hash of the most recent commit in the `data-infrastructure` repository.
1. In the `dev` directory, create a new backend configuration file called `<owner>-<project>-dev.tfbackend`.
    The file will point to the S3 bucket in which we are storing terraform state. Populate the backend
    configuration file with the following (making sure to substitute values for `<owner>` and `<project>`):
    ```hcl
    bucket = "dse-snowflake-dev-terraform-state"
    dynamodb_table = "dse-snowflake-dev-terraform-state-lock"
    key = "<owner>-<project>-dev.tfstate"
    region = "us-west-2"
    ```
1. In the `dev` directory, create a terraform variables file called `terraform.tfvars`,
    and populate the "elt" module variables. These variables may expand in the future,
    but at the moment they are just the new Snowflake organization name, account name and the environment
    (in this case `"DEV"`):
    ```hcl
    organization_name = "<organization_name>"
    account_name = "<account_name>"
    environment = "DEV"
    ```
1. Initialize the configuration:
    ```bash
    terraform init -backend-config <owner>-<project>-dev.tfbackend
    ```
1. Include both Mac and Linux provider binaries in your terraform lock file.
    This helps mitigate differences between CI environments and ODI Macs:
    ```bash
    terraform providers lock -platform=linux_amd64 -platform=darwin_amd64
    ```
1. Add your new `main.tf`, `terraform.tfvars`, `<owner>-<project>-dev.tfbackend`,
    and terraform lock file to the git repository. Do not add the `.terraform/` directory.

## Deploy the dev configuration

1. Ensure that your local environment has environment variables set for `SNOWFLAKE_ACCOUNT`,
    `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY_PATH`,  and `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`,
    and that they are set to your new account, rather than any other accounts.
1. Run `terraform plan` to see the plan for the resources that will be created.
    Inspect the plan to see that everything looks correct.
1. Run `terraform apply` to deploy the configuration. This will actually create the infrastructure!

## Configure and deploy the production configuration

Re-run all of the steps above, but in a new directory `terraform/environments/prd`.
Everywhere where there is a `dev` (or `DEV`), replace it with a `prd` (or `PRD`).
