# Naming Conventions

This page documents the Data Services and Engineering (DSE) team's naming conventions for cloud resources.

## General Approach

Our approach is adapted from [this blog post](https://stepan.wtf/cloud-naming-convention/).
The goals of establishing a naming convetion are:
1. Prevent name collisions between similar resources (especially in cases where names are required to be unique).
1. Allow developers to identify at a glance what a particular resource is and who owns it.
1. Structured naming allows for easier sorting and filtering of resources.

The overall name template is:

```
{owner}-{project}-{env}-[{region}]-[{description}]-[{suffix}]
```
Where `{...}` indicates a component in the name, and `[{...}]` indicates that it is optional or conditionally required.

| **Component** | **Description** | **Required** | **Constraints** |
| ------------- | ------------- | ------------- | ------------- |
**owner** | Owner of the resource | ✔ | len 3-6 |
**project** | Project name | ✔ | len 4-10, a-z0-9 |
**env** | Environment type, e.g. `dev`, `prd`, `stg` | ✔ | len 3, a-z, enum |
**region** | Region (if applicable) | ✗ |  enum
**description** | Additional description (if needed) |  ✗| len 1-20, a-z0-9
**suffix** | Random suffix (only use if there are multiple identical resources) | ✗ | len 3, a-z0-9


**Owner:**
This is a required field.
For most of our projects, it will be `dse` (for Data Services and Engineering),
though it could be other things for projects that we will be handing off to clients upon completion.

**Project:**
A short project name. This is a required field. For general DSE infrastructure, use `infra`.

**Environment:**
The deployment environment. This is a required field.
Generally `prd` (production), `stg` (staging), or `dev` (development).

**Region:**
If the resource exists in a particular region (e.g. `us-west-1`), this should be included.

**Description:**
There may be multiple resources that are identical with respect to the above parameters,
but have a different purpose.
In that case, append a `description` to the name to describe that purpose.
For instance, we might have multiple subnets, some of which are `public` and some of which are `private`. Or we could have multiple buckets for storing different kinds data within the same project.

**Suffix:**
If there all of the above are identical (including `description`),
include a random suffix.
This can be accomplished with the terraform [`random_id`](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) resource.

### Examples

**GCP Project:** We have a GCP project for managing web/product analytics collaborations with the CalInnovate side of ODI. GCP projects to not exist in a region, so a production project could be called `dse-product-analytics-prd`.

**MWAA Environment:** An Apache Airflow environment in AWS does exist in a region, and supports general DSE infrastructure. So a development deployment of the environment could be `dse-infra-dev-us-west-2`.

**Scratch bucket:** We might have several S3 buckets supporting different aspects of a project. For instance, one bucket could be used for scratch work, and another could be used for source data. The scratch bucket could then be named `dse-infra-dev-us-west-1-scratch`.

## Resource tagging

Cloud resources can be tagged with user-specified key-value pairs
which allow for resource and cost tracking within a given cloud account.

Our tagging convention is that information which is available in the resource name should also be available in tags as a specific key-value pair:

| **Key** | **Value** | **Required** |
|---------|-----------|--------------|
| Owner   | `{owner}` | ✔            |
| Project | `{project}`| ✔           |
| Environment | `{env}` | ✔          |
| Description | `{description}` | ✗  |

Note that the `{region}` and `{suffix}` components are not included.
This is because the region information is typically available elsewhere in the API/Console,
and the suffix information is not semantically meaningful.

## Specific considerations

Not all resources can follow the above convention exactly.
For instance, some resource names may not allow hyphens, or may have length limits.
In those cases, we should try to adhere to the conventions as closely as possible
(e.g., by substituting underscores for hyphens)
and document the exception here.

### Cloud data warehouse schemas

Data warehouse schemas (or datasets in BigQuery) are often user/analyst-facing,
and have different considerations.
They usually [cannot have hyphens in them](https://cloud.google.com/bigquery/docs/datasets#dataset-naming), so words should be separated with underscores "`_`".
Furthermore, analysts needn't need to know details of regions or deployments, so `region` and `env` are dropped, and the naming convention becomes:

```
{owner}_{project}_[{description}]
```

If a project is owned by the Data Services and Engineering team,
the `owner` component may be ommited, and the schema name is simply
```
{project}_[{description}]
```
Note that Snowflake [normalizes all object names to upper case](https://docs.snowflake.com/en/sql-reference/identifiers-syntax).
This is opposite to how [PostgreSQL normalizes object names](https://www.postgresql.org/docs/current/sql-syntax-lexical.html) (sigh).
Most of the time this doesn't matter, but occasionally requires thought if you have a mixed-case object name. If you are naming new database tables or schemas, mixed-case identifiers should be avoided.

### dbt

Models in a data warehouse do not follow the same naming conventions as raw cloud resources,
as their most frequent consumers are analytics engineers and data analysts.

**Dimension tables** are prefixed with `dim_`.

**Fact tables** are prefixed with `fct_`.

**Staging tables** are prefixed with `stg_`.

**Intermediate tables** are prefixed with `int_`.

We may adopt additional conventions for denoting aggregations, column data types, etc. in the future.

Feature branches in dbt are tested in separate schemas within the cloud data warehouse.
When a developer uses dbt locally or in dbt Cloud, they choose a name for the development schema.
By convention, this is `dbt_{username}`, where `username` is the first initial of their given name followed by their surname.

### Fivetran

The names of tables loaded by Fivetran are typically set by either Fivetran or the names of the tables in the source systems.
As such, we don't have much control over them, and they won't adhere to any particular naming conventions.

Fivetran connectors names cannot contain hyphens, and should follow this pattern:

```
fivetran_{owner}_{project}_{connector_type}_[{description}]
```
The schemas into which a fivetran connector is writing should be named the same as the connector
(which is why the connector name has some seemingly redundant information).

If a project is owned by the Data Services and Engineering team,
the `owner` component may be ommited, and the schema name is simply
```
fivetran_{project}_{connector_type}_[{description}]
```

## External References

- https://docs.getdbt.com/blog/stakeholder-friendly-model-names
- https://docs.getdbt.com/blog/on-the-importance-of-naming
