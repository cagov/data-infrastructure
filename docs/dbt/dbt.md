# dbt on the Data Services and Engineering team

## Architecture

We broadly follow the architecture described in
[this dbt blog post](https://www.getdbt.com/blog/how-we-configure-snowflake/)
for our Snowflake dbt project.

It is described in more detail in our [Snowflake docs](../infra/snowflake.md#architecture).

## Naming conventions

Models in a data warehouse do not follow the same naming conventions as [raw cloud resources](../learning/naming-conventions.md#general-approach),
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
