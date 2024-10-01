# Tearing down a project

Upon completion of a project (or if you just went through project setup for testing purposes)
there are a few steps needed to tear down the infrastructure.

1. If the GitHub repository is to be handed off a client, transfer ownership of it to them.
    Otherwise, delete or archive the GitHub repository.
    If archiving, delete the GitHub actions secrets.
1. Open a Help Desk ticket with IT-Ops to remove Sentinel logging for the Snowflake account.
1. If the Snowflake account is to be handed off to a client, transfer ownership of it to them.
    Otherwise, [drop the account](https://docs.snowflake.com/en/user-guide/organizations-manage-accounts-delete).
