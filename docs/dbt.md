# dbt on the Data Services and Engineering team

## New project setup

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

You'll also want to [configure notifications for job failures](Configure notifications for job failures).

Pictured below is an example of environment variables you can set for each environment. For more guidance, read [dbt's docs on environment variables](https://docs.getdbt.com/docs/build/environment-variables).

![environment variables](images/environment_variables.png)

## Architecture

We broadly follow the architecture described in
[this dbt blog post](https://www.getdbt.com/blog/how-we-configure-snowflake/)
for our Snowflake dbt project.

It is described in more detail in our [Snowflake docs](./snowflake.md#architecture).

## Naming conventions

Models in a data warehouse do not follow the same naming conventions as [raw cloud resources](./naming-conventions.md#general-approach),
as their most frequent consumers are analytics engineers and data analysts.

The following conventions are used where appropriate:

**Dimension tables** are prefixed with `dim_`.

**Fact tables** are prefixed with `fct_`.

**Staging tables** are prefixed with `stg_`.

**Intermediate tables** are prefixed with `int_`.

We may adopt additional conventions for denoting aggregations, column data types, etc. in the future.
If during the course of a project's model development we determine that simpler human-readable names
work better for our partners or downstream consumers, we may drop the above prefixing conventions.

## Custom schema names

dbt's default method for generating [custom schema names](https://docs.getdbt.com/docs/build/custom-schemas)
works well for a single-database setup:

* It allows development work to occur in a separate schema from production models.
* It allows analytics engineers to develop side-by-side without stepping on each others toes.

A downside of the default is that production models all get a prefix,
which may not be an ideal naming convention for end-users.

Because our architecture separates development and production databases,
and has strict permissions protecting the `RAW` database,
there is less danger of breaking production models.
So we use our own custom schema name following a modified
[approach from the GitLab Data Team](https://gitlab.com/gitlab-data/analytics/-/blob/master/transform/snowflake-dbt/macros/utils/override/generate_schema_name.sql).

In production, each schema is just the custom schema name without any prefix.
In non-production environments the default is used, where analytics engineers
get the custom schema name prefixed with their target schema name (i.e. `dbt_username_schemaname`),
and CI runs get the custom schema name prefixed with a CI job name.

This approach may be reevaluated as the project matures.

## Developing against production data

Our Snowflake architecture allows for reasonably safe `SELECT`ing from the production `RAW` database while developing models.
While this could be expensive for large tables,
it also allows for faster and more reliable model development.

To develop against production `RAW` data, first you need someone with the `USERADMIN` role to grant rights to the `TRANSFORMER_DEV` role
(this need only be done once, and can be revoked later):

```sql
USE ROLE USERADMIN;
GRANT ROLE RAW_PRD_READ TO ROLE TRANSFORMER_DEV;
```

!!! note
    This grant is not managed via terraform in order to keep the configurations of
    different environments as logically separate as possible. We may revisit this
    decision should the manual grant cause problems.

You can then run dbt locally and specify the `RAW` database manually:

```bash
DBT_RAW_DB=RAW_PRD dbt run
```
