### Create service accounts using Terraform

Service accounts aren't associated with a human user.
Instead, they are created by an account administrator for
the purposes of allowing another service to perform some action.

We currently use service accounts for:

* Fivetran loading raw data
* Airflow loading raw data
* dbt Cloud for transforming data
* GitHub actions generating docs

These service accounts are created using Terraform
and assigned roles according to the principle of least-privilege.
They use key pair authentication, which is more secure than password-based authentication as no sensitive data are exchanged.
Private keys for service accounts should be stored in CalData's 1Password vault.

The following are steps for creating a new service account with key pair authentication:

1. Create a new key pair in accordance with [these docs](https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-authentication).
  Most of the time, you should create a key pair with encryption enabled for the private key.
1. Add the private key to the CalData 1Password vault, along with the intended service account user name and passphrase (if applicable)
1. Create a new user in the Snowflake Terraform configuration (`users.tf`) and assign it the appropriate functional role.
  Once the user is created, add its public key in the Snowflake UI:
  ```sql
  ALTER USER <USERNAME> SET RSA_PUBLIC_KEY='MII...'
  ```
  Note that we need to remove the header and trailer (i.e. `-- BEGIN PUBLIC KEY --`) as well as any line breaks
  in order for Snowflake to accept the public key as valid.
1. Add the *private* key for the user to whatever system needs to access Snowflake.

Service accounts should not be shared across different applications,
so if one becomes compromised, the damage is more isolated.
