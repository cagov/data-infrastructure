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
    1. Save the Account Locator and URL for your new account.
1. Log into your new account. You should be prompted to change your password. Save the updated password in your password manager.

### Enable multi-factor authentication for your user

1. Ensure the Duo Mobile app is installed on your phone.
1. In the upper-left corner, click on your user, and select "Profile"
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
    can be helpful for quickly creating a new encrypted key pair.
1. In your local `.bash_profile` or an `.env` file, add environment variables for
    `SNOWFLAKE_PRIVATE_KEY_PATH` and (if applicable) `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`.

### Apply a session policy

By default, Snowflake logs out user sessions after four hours of inactivity.
ODI's information security policies prefer that we log out after one hour of inactivity for most accounts,
and after fifteen minutes of inactivity for particularly sensitive accounts.

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

## Create project git repository

## Deploy project infrastructure using Terraform

1. Create a directory for your project structure
1. Copy the Terraform configuration from ...
1. Rename `carb-enforcement-dev.tfbackend` to `user-journey-dev.tfbackend`
1. Change the key in the `tfbackend`
1. Update the variables
    1. Environment
    1. Region

1. `terraform init -backend-config user-journey-dev.tfbackend`

## Set up CI in GitHub

### Add key pairs to the GitHub service accounts

### Set up GitHub actions secrets

### Enable GitHub pages for the repository
