# fivetran project setup

To set up a new project in Fivetran follow these steps:

1. First, ensure you have met the following pre-requisites:
    - You have set up a Snowflake Account for the project (follow all instructions from [here](./snowflake-setup.md))
    - Ensure that your Snowflake project has a **LOADER_PRD** role with privileges to write data to the **RAW_PRD** database
    - You have created a Snowflake User called **FIVETRAN_SVC_USER_PRD** and ensured this user has the **LOADER_PRD** role
    - You have set up an auth key pair for this user and saved it to the ODI OnePass account

2. In Fivetran, navigate to Organization -> Accounts
3. Click _Add Acount_ 
4. Choose an Account Name, select _Enterprise_ for Account Tier and _No restrictions_ for Required Authentication Type
5. Next, navigate to Destinations 
6. Search for **Snowflake** and click _Select_
7. To set up the Snowflake connector:
    1. Name the destination **RAW_PRD**
    2. Add the Snowflake URL for your project as the _Host_
    3. Add the Port for your Snowflake project as the _Port_
    4. Add **FIVETRA_SVC_USER_PRD** as the _User_
    5. Add **RAW_PRD** as the _Database_
    6. For _Auth_ select **KEY_PAIR** and enter the key pair details for the FIVETRAN_SVC_USER_PRD user
    6. Add **LOADER_PRD** as the _Role_
    7. Select your _Cloud service provider_, _Cloud region_, and _Default Time Zone_ 
8. Click the _Save & Test_ button

Once you are through with these steps, you can proceed to creating and assigning permissions to Users in the Fivetran account.
