# Working with Snowflake Code Artifacts

Snowflake has a few first-class code objects which are stored in databases:

* **Notebooks**: notebook files (`.ipynb`) allow for mixing SQL statements,
    Python code, narrative prose, and visualizations. They can be useful for exploratory
    data analysis, and as a means for sharing data driven documents.
* **Streamlit dashboards**: Streamlit dashboards allow for interactive data visualizations
    which can be shared with the organization.

A downside of these objects is that it is more difficult to track, version
and maintain high code quality for them.
This document includes some recommendations and best practices for working with
notebooks and Streamlit dashboards within Snowflake.

!!! note
    The DOE team's thinking about whether/when to use these objects is still a moving target.
    These recommendations are weakly-held, and subject to change.


## Store notebooks and dashboards in the `ANALYTICS` layer

Since notebooks and dashboards are most frequently used as reporting products,
they are most appropriate for the `ANALYTICS`/marts layer. This means:

1. Create them in the `ANALYTICS_{env}` database.
1. Create them using the `REPORTER_{env}` role.
1. Use the `REPORTING_XS_{env}` warehouse for queries.

**Warning: Streamlit dashboards execute using the role of their owner.
People with edit permissions on the dashboard may be able to use them for privilege escalation
if the dashboard is owned by a powerful role.**
Using the `REPORTER` role means that the dashboard will not be able
to access data from the `RAW` or `TRANSFORM` layers,
nor will it be able to edit data in the `ANALYTICS` layer.
This is a useful security feature, and consistent with our RBAC
design. In development it may be useful to use the `TRANSFORMER` role,
but "production" dashboards should endeavor to use `REPORTER_PRD`.


## Use extra-small warehouses

Notebooks and Streamlit dashboards might be active for significantly longer
than the actual query times for the data backing them.
It's not unusual for a notebook to be running for most of the day as an analyst works.
To save on compute and avoid surprise cost overruns, always use an extra small warehouse.

If more expensive queries are needed, consider pre-building tables in the `ANALYTICS` database
and making sure appropriate filters are used to cut down on data scans.

## Use version control

Use of version control with notebooks and Streamlit dashboards is still important.
We recommend ensuring that any object be in version control and fully reproducible if any of the following are true:

1. It is shared outside of the immediate DOE team
1. It is used for any recommendation, publication, or data product
1. It is used operationally (i.e., someone looks in on it regularly).

### Connecting a repository

*Note: this only needs to be done once per Snowflake environment and GitHub repository.
Specific roles and permission grants are provisional, and it would be nice to clean it up a bit*

1. Create a scoped fine-grained personal access token for repository access.
1. Create development and production versions of the repository. The following SQL
    script can be used to set up the repos. Depending on the situation, some
    parts of it may not be necessary, or the repository may need to be created in
    a different set of databases/schemas, so read through with some care.
    ```sql
    use role accountadmin;

    /* First, we create secrets for the GitHub authentication
       as well as the API integration so we can talk to GitHub
       We can use a fine-grained token that only has read access
       to a single repository for safety. Still not ideal that it's a user
       token rather than an OAuth app or similar, but that seems to
       be the only way to do it.
    */
    create or replace secret analytics_prd.public.gh_token
    type = password
    username = '<GitHub username>'
    password = '<token here>';

    create or replace secret analytics_dev.public.gh_token
    type = password
    username = '<GitHub username>'
    password = '<token here>';

    create or replace api integration cagov_github
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/cagov')
    allowed_authentication_secrets = ('analytics_dev.public.gh_token', 'analytics_prd.public.gh_token')
    enabled = true;

    -- Grant usage on the secret and API integration to the transformer roles
    grant usage on integration cagov_github to role transformer_dev;
    grant usage on secret analytics_dev.public.gh_token to role transformer_dev;
    grant usage on integration cagov_github to role transformer_prd;
    grant usage on secret analytics_prd.public.gh_token to role transformer_prd;

    -- Grant the ability to create GitHub repos and Streamlit apps on PUBLIC to the transformer roles.
    -- These are things we can move to our default terraform configuration.
    use role sysadmin;
    grant create git repository on schema analytics_dev.public to role transformer_dev;
    grant create git repository on schema analytics_prd.public to role transformer_prd;
    grant create streamlit on schema analytics_dev.public to role transformer_dev;
    grant create streamlit on schema analytics_prd.public to role transformer_prd;


    -- Create the Git reepositories in dev and prod
    use role transformer_dev;
    create or replace git repository analytics_dev.public."<repo-name>"
    origin = 'https://github.com/cagov/<repo-name>'
    api_integration = 'CAGOV_GITHUB'
    git_credentials = 'analytics_dev.public.gh_token';

    use role transformer_prd;
    create or replace git repository analytics_prd.public."<repo-name>"
    origin = 'https://github.com/cagov/<repo-name>'
    api_integration = 'CAGOV_GITHUB'
    git_credentials = 'analytics_prd.public.gh_token';
    ```

This repository can now be used with notebooks and Streamlit dashboards.

### Creating a notebook or Streamlit dashboard

There are two different scenarios we want to address here:

1. Creating a new notebook or dashboard in a Git repository
1. Connecting an existing notebook or dashboard to a Git repository

#### Creating a new notebook/dashboard

1. Create a new branch for the object in your git repository
    (the Snowflake UI doesn't have a way to create branches):
    ```bash
    git switch -c <new-branch-name>
    ```
1. In the upper left of the notebook/Streamlit page click the "down" caret
    and choose "Create from repository"
1. Give the notebook/Streamlit a descriptive name. **Warning: notebooks cannot
    have their name changed after the fact. Be sure to choose wisely, otherwise
    you may need to re-create it in a new branch**
1. In "File location in the repository", find the Git repository in Snowflake,
    select the branch you created above,
    and navigate to the path you want for the notebook/Streamlit in the repository.
    For instance, we might have a `notebooks` or `streamlit` subdirectory.
1. Choose the database location for the object (e.g., `ANALYTICS_DEV.PUBLIC`)
1. Choose the warehouse for the object (e.g., `REPORTING_XS_DEV`).

#### Connecting an existing notebook/dashboard

1. In the left side panel for the notebook/Streamlit, click the "Connect Git Repository" button
1. In "File location in the repository", find the Git repository in Snowflake,
    select the branch you created above,
    and navigate to the path you want for the notebook/Streamlit in the repository.
    For instance, we might have a `notebooks` or `streamlit` subdirectory.
1. Add a commit message and push the commit adding the object to GitHub.
    If this is your first commit in Snowflake you will need to add a
    [personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).
    *In general, this personal access token will not be the same one used in
    the repo set-up process.*

## Dev/Prod promotion

TODO

### Where to build data

TODO
