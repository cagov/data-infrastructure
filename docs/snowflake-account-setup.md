# New Project Setup

The DSE team regularly creates new Snowflake accounts in our Snowflake org.
We do this instead of putting all of our data projects into our main account for a few reasons:

1. At the end of a project, we often want to transfer account ownership to our partners.
    Having it separated from the start helps that process.
1. We frequently want to add our project champion or IT partners to our account as admins.
    This is safer if project accounts are separate.
1. We often want to have accounts in a specific cloud and region for compliance or data transfer regions.
1. Different projects may require different approaches to account-level operations like OAuth/SAML.

Here we document the steps to creating a new Snoflake account from scratch.

## Prerequisites

### Obtain permissions in Snowflake

In order to create a new account, you will need access to the `orgadmin` role.
If you have `accountadmin` in the primary Snowflake account, you can grant it to yourself:

```sql
USE ROLE accountadmin;
GRANT ROLE orgadmin TO USER <YOUR-USER>;
```

### Get access to AWS

We typically create our Snowflake architecture using Terraform.
Terraform state is stored in S3 buckets within our AWS account,
so you will need read/write access to those buckets.

Ask a DSE AWS admin to give you access to these buckets,
and [configure your AWS credentials](./setup.md#aws).


### Install terraform dependencies

You can install Terraform using whatever approach makes sense for your system,
including using `brew` or `conda`.

Here is a sample for installing the dependencies using `conda`:

```bash
conda create -n infra python=3.10  # create an environment named 'infra'
conda activate infra  # activate the environment
conda install -c conda-forge terraform tflint  # Install terraform and tflint
```

## Snowflake account setup

### Create the account

1. Assume the `ORGADMIN` role (you may need to log out and log back in to see it)
1. Under the `Admin` side panel, go to `Accounts` and create a new account:
    1. Select the cloud and region appropriate to the project. The region should be in the US.
    1. Select "Business Critical" for the Snowflake Edition.
    1. You will be prompted to create an initial user with `ACCOUNTADMIN` privileges. This should be you. You will be prompted to create a password for your user. Create one using your password manager, but know that it will ask you change your password upon first log-in.
    1. Save the Account Locator and URL for your new account.
1. Log into your new account. You should be prompted to change your password. Save the updated password in your password manager.

### Enable multi-factor authentication for your user

### Set up key pair authentication

### Apply a session policy

By default,

### Add IT-Ops representatives

## Deploy project infrastructure using Terraform

1. Create a directory for your project structure
1. Install `terraform` and `tflint`
    ```bash
    conda install -c conda-forge terraform tflint
    ```
1. Copy the Terraform configuration from ...
1. Rename `carb-enforcement-dev.tfbackend` to `user-journey-dev.tfbackend`
1. Change the key in the `tfbackend`
1. Update the variables
    1. Environment
    1. Region
1. Install awscli
    ```bash
    aws install -c conda-forge awscli
    ```
    1. Run `aws configure`
    1. Generate an AWS access key
    1. etc

1. `terraform init -backend-config user-journey-dev.tfbackend`

## Set up CI in GitHub

### Add key pairs to the GitHub service accounts

### Set up GitHub actions secrets

### Enable GitHub pages for the repository
