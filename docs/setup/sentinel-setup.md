# Set up Sentinel logging

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

    * The account locator # Legacy account identifier
    * The organization name
    * The account name (distinct from the account locator)
      * Note : The preferred account identifier is to use name of the account prefixed by its organization (e.g. myorg-account123)
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
