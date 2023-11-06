# New Project Setup

The DSE team regularly creates new Snowflake accounts in our Snowflake org.
We do this instead of putting all of our data projects into our main account for a few reasons:

1. At the end of a project, we often want to transfer account ownership to our partners.
    Having it separated from the start helps that process.
1. We frequently want to add our project champion or IT partners to our account as admins.
    This is safer if project accounts are separate.
1. We often want to have accounts in a specific cloud and region for compliance or data transfer regions.
1. Different projects may require different approaches to account-level operations like OAuth/SAML.

Here we document the steps to creating a new Snowflake account from scratch.

## Prerequisites

### Obtain permissions in Snowflake

In order to create a new account, you will need access to the `orgadmin` role.
If you have `accountadmin` in the primary Snowflake account, you can grant it to yourself:

```sql
USE ROLE accountadmin;
GRANT ROLE orgadmin TO USER <YOUR-USER>;
```

If you later want to revoke the `orgadmin` role from your user or any other, you can do so with:

```sql
USE ROLE accountadmin;
REVOKE ROLE orgadmin FROM USER <YOUR-USER>;
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

1. Assume the `ORGADMIN` role
1. Under the "Admin" side panel, go to "Accounts" and click the "+ Account" button:
    1. Select the cloud and region appropriate to the project. The region should be in the United States.
    1. Select "Business Critical" for the Snowflake Edition.
    1. You will be prompted to create an initial user with `ACCOUNTADMIN` privileges. This should be you.
        You will be prompted to create a password for your user. Create one using your password manager,
        but know that it will ask you change your password upon first log-in.
    1. Save the Account Locator and Account URL for your new account.
1. Log into your new account. You should be prompted to change your password. Save the updated password in your password manager.

### Enable multi-factor authentication for your user

1. Ensure the Duo Mobile app is installed on your phone.
1. In the upper-left corner of the Snowsight UI, click on your username, and select "Profile"
1. At the bottom of the dialog, select "Enroll" to enable multi-factor authentication.
1. Follow the instructions to link the new account with your Duo app.

### Set up key pair authentication

Certain Snowflake clients don't properly cache MFA tokens,
which means that using them can generate dozens or hundreds of MFA requests on your phone.
At best this makes the tools unusable, and at worst it can lock your Snowflake account.
One example of such a tool is (as of this writing) the Snowflake Terraform Provider.

The recommended workaround for this is to add a key pair to your account for use with those tools.

1. Follow the instructions given [here](https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-authentication)
    to generate a key pair and add the public key to your account.
    Keep the key pair in a secure place on your device.
    [This gist](https://gist.github.com/ian-r-rose/1c714ee04be53f7a3fd80322e1a22c27)
    contains the bash commands from the instructions,
    and can be helpful for quickly creating a new encrypted key pair.
    Usage of the script looks like:
    ```bash
    bash generate_encrypted_key.sh <key-name> <passphrase>
    ```
    You can use `pbcopy < _your_public_key_file_name_.pub` to copy the contents of your public key.
    Be sure to remove the `----BEGIN PUBLIC KEY----` and `-----END PUBLIC KEY------` portions
    when adding your key to your Snowflake user.
1. In your local `.bash_profile` or an `.env` file, add environment variables for
    `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY_PATH`,
    and (if applicable) `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`.

### Apply a session policy

By default, Snowflake logs out user sessions after four hours of inactivity.
ODI's information security policies prefer that we log out after one hour of inactivity for most accounts,
and after fifteen minutes of inactivity for particularly sensitive accounts.

!!! note
    It's possible we will do this using Terraform in the future,
    but at the time of this writing the Snowflake Terraform provider does not support session policies.

After the Snowflake account is created, run the following script in a worksheet
to set the appropriate session policy:

```sql
use role sysadmin;
create database if not exists policies;
create session policy if not exists policies.public.account_session_policy
  session_idle_timeout_mins = 60
  session_ui_idle_timeout_mins = 60
;
use role accountadmin;
-- alter account unset session policy;  -- unset any previously existing session policy
alter account set session policy policies.public.account_session_policy;
```

### Add IT-Ops representatives

TODO: establish and document processes here.

### Set up Okta SSO and SCIM

TODO: establish and document processes here.

## Create project git repository

Create a new git repository from the CalData Infrastructure Template
following the instructions [here](https://github.com/cagov/caldata-infrastructure-template#usage).

Once you have created the repository, push it to a remote repository in GitHub.
There are some GitHub actions that will fail because the repository is not yet
configured to work with the new Snowflake account.

## Deploy project infrastructure using Terraform

We will create two separate deployments of the project infrastructure,
one for development, and one for production.
In some places we will refer to project name and owner as `<project>` and `<owner>`, respectively,
following our [naming conventions](./naming-conventions.md).
You should substitute the appropriate names there.

### Create the dev configuration

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
    The file will point to the S3 bucket in which we are storing terraform state:
    ```hcl
    bucket = "dse-snowflake-dev-terraform-state"
    dynamodb_table = "dse-snowflake-dev-terraform-state-lock"
    key = "<owner>-<project>-dev.tfstate"
    region = "us-west-2"
    ```
1. In the `dev` directory, create a terraform variables file called `terraform.tfvars`,
    and populate the "elt" module variables. These variables may expand in the future,
    but at the moment they are just the new Snowflake account locator and the environment
    (in this case `"DEV"`):
    ```hcl
    locator     = "<account-locator>"
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

### Deploy the dev configuration

1. Ensure that your local environment has environment variables set for `SNOWFLAKE_ACCOUNT`,
    `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY_PATH`,  and `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`,
    and that they are set to your new account, rather than any other accounts.
1. Run `terraform plan` to see the plan for the resources that will be created.
    Inspect the plan to see that everything looks correct.
1. Run `terraform apply` to deploy the configuration. This will actually create the infrastructure!

### Configure and deploy the production configuration

Re-run all of the steps above, but in a new directory `terraform/environments/prd`.
Everywhere where there is a `dev` (or `DEV`), replace it with a `prd` (or `PRD`).

## Set up Sentinel logging

ODI IT requires that systems log to our Microsoft Sentinel instance
for compliance with security monitoring policies.
The terraform configuration deployed above creates a service account for Sentinel
which needs to be integrated.

1. Create a password for the Sentinel service account.
    In other contexts we prefer key pairs for service accounts, but the Sentinel
    integration requires password authentication. In a Snowflake worksheet run:
    ```sql
    use role securityadmin;
    alter user sentinel_svc_user_prd set password = '<new-password>'
    ```
1. Store the Sentinel service account authentication information in our shared
    1Password vault.
    Make sure to provide enough information to disambiguate it from others stored in the vault,
    including:

    * The account locator
    * The account name (distinct from the account locator)
    * The service account name
    * The public key
    * The private key

1. Create an IT Help Desk ticket to add the new account to our Sentinel instance.
    Share the 1Password item with the IT-Ops staff member who is implementing the ticket.
    If you've included all of the above information in the vault item,
    it should be all they need.
1. Within fifteen minutes or so of implementation it should be clear whether the integration is working.
    IT-Ops should be able to see logs ingesting, and Snowflake account admins should see queries
    from the Sentinel service user.

## Set up CI in GitHub

The projects generated from our infrastructure template need read access to the
Snowflake account in order to do two things from GitHub actions:

1. Verify that dbt models in branches compile and pass linter checks
1. Generate dbt docs upon merge to `main`.

The terraform configurations deployed above create two service accounts
for GitHub actions, a production one for docs and a dev one for CI checks.

### Add key pairs to the GitHub service accounts

Set up key pairs for the two GitHub actions service accounts
(`GITHUB_ACTIONS_SVC_USER_DEV` and `GITHUB_ACTIONS_SVC_USER_PRD`).
This follows a similar procedure to what you did for your personal key pair,
though the project template currently does not assume an encrypted key pair.
[This bash script](https://gist.github.com/ian-r-rose/35d49bd253194f57b57e9e59a595bed8)
is a helpful shortcut for generating the key pair:
```bash
bash generate_key.sh <key-name>
```

Once you have created and set the key pairs, add them to the DSE 1Password shared vault.
Make sure to provide enough information to disambiguate the key pair from others stored in the vault,
including:

* The account locator
* The account name (distinct from the account locator)
* The service account name
* The public key
* The private key

### Set up GitHub actions secrets

You need to configure secrets in GitHub actions
in order for the service accounts to be able to connect to your Snowflake account.
From the repository page, go to "Settings", then to "Secrets and variables", then to "Actions".

Add the following repository secrets:

| Variable | Value |
|----------|-------|
| `SNOWFLAKE_ACCOUNT` | new account locator |
| `SNOWFLAKE_USER_DEV` | `GITHUB_ACTIONS_SVC_USER_DEV` |
| `SNOWFLAKE_USER_PRD` | `GITHUB_ACTIONS_SVC_USER_PRD` |
| `SNOWFLAKE_PRIVATE_KEY_DEV` | dev service account private key |
| `SNOWFLAKE_PRIVATE_KEY_PRD` | prd service account private key |

### Enable GitHub pages for the repository

The repository must have GitHub pages enabled in order for it to deploy and be viewable.

1. From the repository page, go to "Settings", then to "Pages".
1. Under "GitHub Pages visibility" select "Private" (unless the project is public!).
1. Under "Build and deployment" select "Deploy from a branch" and choose "gh-pages" as your branch.


## Tearing down a project

Upon completion of a project (or if you just went through the above for testing purposes)
there are a few steps needed to tear down the infrastructure.

1. If the GitHub repository is to be handed off a client, transfer ownership of it to them.
    Otherwise, delete or archive the GitHub repository.
    If archiving, delete the GitHub actions secrets.
1. Open a Help Desk ticket with IT-Ops to remove Sentinel logging for the Snowflake account.
1. If the Snowflake account is to be handed off to a client, transfer ownership of it to them.
    Otherwise, [drop the account](https://docs.snowflake.com/en/user-guide/organizations-manage-accounts-delete).
