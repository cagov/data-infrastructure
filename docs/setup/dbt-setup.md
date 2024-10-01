# dbt Project Setup

To set up a new project on dbt Cloud follow these steps:

1. Give your new project a name.
1. Click *Advanced settings* and in the *Project subdirectory* field, enter "transform"
1. Select a data warehouse connection. (e.g. Snowflake, BigQuery, Redshift)
1. For the *Development credentials* section you'll want to:
    1. Under *Auth method* select *Key pair*
    1. Enter your data warehouse username
    1. Enter the private key amd private key passphrase
    1. For more guidance, read [dbt's docs on connecting to Snowflake via key pair](https://docs.getdbt.com/docs/cloud/connect-data-platform/connect-snowflake#key-pair)
1. Finally click the *Test Connection* button.
1. Connect the appropriate repository (usually GitHub). Read [dbt's docs on connecting to GitHub](https://docs.getdbt.com/docs/cloud/git/connect-github).

Once you're through the first five steps you can return to the dbt homepage and click the Settings button in the upper right corner. From there you can follow the steps to configure three environments for Continuous intergation - CI, development, and production. Read [dbt's docs on CI in dbt Cloud](https://docs.getdbt.com/docs/deploy/continuous-integration). Read [dbt's docs on creating production (deployment) environments](https://docs.getdbt.com/docs/deploy/deploy-environments) and [dbt's docs on creating and scheduling deploy jobs](https://docs.getdbt.com/docs/deploy/deploy-jobs#create-and-schedule-jobs).

You'll also want to [configure notifications for job failures](https://docs.getdbt.com/docs/deploy/job-notifications).

Pictured below is an example of environment variables you can set for each environment. For more guidance, read [dbt's docs on environment variables](https://docs.getdbt.com/docs/build/environment-variables).

![environment variables](../images/environment_variables.png)
