# New project setup

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
and [configure your AWS credentials](../code/local-setup.md#aws).


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
        but know that it will ask you to change your password upon first log-in.
    1. Save the Account Locator, Organization name, Account name and Account URL for your new account.
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

### Developing against production data

Our Snowflake architecture allows for reasonably safe `SELECT`ing from the production databases while developing models.
While this could be expensive for large tables, it also allows for faster and more reliable model development.

To develop against production data, first you need someone with the `USERADMIN` role to grant rights to the `TRANSFORMER_DEV` role (this need only be done once, and can be revoked later). These grants enable access to real data for development and facilitate cloning and deferral for large-table projects:

```sql
USE ROLE USERADMIN;
GRANT ROLE RAW_PRD_READ TO ROLE TRANSFORMER_DEV;
GRANT ROLE TRANSFORM_PRD_READ TO ROLE TRANSFORMER_DEV;
GRANT ROLE ANALYTICS_PRD_READ TO ROLE TRANSFORMER_DEV;
```

!!! note
    These grants are not managed via Terraform in order to keep the configurations of
    different environments as logically separate as possible. We may revisit this
    decision should the manual grants cause problems.

You can then run dbt locally and specify the `RAW` database manually:

```bash
DBT_RAW_DB=RAW_PRD dbt run
```

### Streamlit dashboard development

All production Streamlit dashboards and their marts should reside in the `ANALYTICS_{env}_PRD` database.
If a dashboard needs access to objects from earlier layers, they should be exposed via explicitly created mart tables in this database.

To support Streamlit development, the `REPORTER_DEV` role may need read access to the production marts:

```sql
USE ROLE USERADMIN;
GRANT ROLE ANALYTICS_PRD_READ TO ROLE REPORTER_DEV;
```


### Add IT-Ops representatives

TODO: establish and document processes here.

### Set up Okta SSO and SCIM

TODO: establish and document processes here.
