# Working with Snowflake Code Artifacts

Snowflake has a few first-class code objects which are stored in databases:

* **Notebooks**: notebook files (`.ipynb`) allow for mixing SQL statements,
    Python code, narrative prose, and visualizations. They can be useful for exploratory
    data analysis, and as a means for sharing data driven documents.
* **Streamlit dashboards**: Streamlit dashboards allow for interactive data visualizations
    which can be shared with the organization.

A downside of these objects is that it is more difficult to track, version,
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

Using the `REPORTER` role means that the dashboard will not be able
to access data from the `RAW` or `TRANSFORM` layers,
nor will it be able to edit data in the `ANALYTICS` layer.
This is a useful security feature, and consistent with our RBAC
design.

One consequence of this recommendation is that every table/view used
by the notebook or dashboard should *also* be in the `ANALYTICS` layer.
In development it may be useful to use the `TRANSFORMER` role,
but "production" dashboards should endeavor to use `REPORTER_PRD`.
Getting the appropriate data in `ANALYTICS` for consumption may take some extra work,
we recommend using the guidelines [here](#use-version-control) to assess when it is appropriate.


!!! warning
    Streamlit dashboards execute using the role of their owner.
    Malicious users with edit permissions on the dashboard may be able to use them for
    [privilege escalation](https://en.wikipedia.org/wiki/Privilege_escalation)
    if the dashboard is owned by a powerful role.
    Even for users with good intentions, it may be possible to accidentally cause problems.
    Using the `REPORTER_{env}` role is for Streamlit dashboards is an application of the
    [principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege).
    For more discussion of Streamlit dashboard security, see
    [these docs](https://docs.snowflake.com/en/developer-guide/streamlit/owners-rights#owner-s-rights-and-app-security).


## Use extra-small warehouses

Notebooks and Streamlit dashboards involve two separate Snowflake warehouses, the one powering their
[Python kernel](https://docs.snowflake.com/en/user-guide/warehouses-overview#label-default-warehouse),
and the one powering their SQL queries.
The Python kernel is active as long as the notebook/dashboard is active, while the query warehouse may
auto-suspend when no queries are being executed.
As such, it's not unusual for the warehouse cost of running and developing the notebook/dashboard
to be more than  that of the warehouse cost of its queries.

To save on compute and avoid surprise cost overruns,
always use the default (extra-small) `SYSTEM$STREAMLIT_NOTEBOOK_WH` for the kernel,
and select an extra small warehouse for queries.
If more expensive queries are needed, consider pre-building tables in the `ANALYTICS` database
and making sure appropriate filters are used to cut down on data scans.

## Use version control

Use of version control with notebooks and Streamlit dashboards is still important.
We recommend ensuring that any object be in version control and fully reproducible if any of the following are true:

1. It is shared outside of the immediate DOE team.
1. It is used for any recommendation, publication, or data product.
1. It is used operationally (i.e., someone looks in on it regularly).

### Connecting a repository

*Note: this only needs to be done once per Snowflake environment and GitHub repository.
Specific roles and permission grants are provisional, and it would be nice to clean it up a bit*

1. Create a scoped fine-grained personal access token for repository access.
    This fine-grained token only needs *Read-only* access to the relevant repository.
    It's worthwhile to keep the token scope minimal, as everyone with access to the
    git repository in Snowflake will be using this token.
1. Create development and production versions of the repository in Snowflake. The following SQL
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

### Getting a Snowflake notebook or dashboard into a git repository

There are two different scenarios we want to address here:

1. Creating a new notebook or dashboard in Snowflake based on an existing file in a Git repository
1. Adding an existing notebook or dashboard in Snowflake to a Git repository

In both cases, you should have a `REPORTER_{env}` role selected in the
Snowflake role switcher in the bottom left.

!!! warning
    Somewhat annoyingly, it's difficult-to-impossible to change the name of notebooks and dashboards
    after they are created in Snowflake, as well as their paths in a Git repository.
    When choosing file names, we recommend the following:

    * Use simple, descriptive file names describing what the notebook/dashboard does.
    * Do not use Snowflake unique identifiers for file names: these will not be stable between branches.
    * Avoid any references to things like "prod" or "final" or "use this one" in the name:
        these will quickly become incorrect with a branching git-based workflow.


As a prerequisite to this, you should create a GitHub
[personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).
allowing you to make commits within the Snowflake UI under your name.
We recommend creating a [fine-grained token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token),
with "Read and Write" access to "Contents" for the relevant repositories.
Creating this token will likely need approval from a GitHub organization admin.

#### Creating a new notebook/dashboard in Snowflake based on an existing file in a Git repository

1. Create a new branch for the object in your git repository
    (the Snowflake UI doesn't have a way to create branches):
    ```bash
    git switch -c <new-branch-name>
    ```
1. In the upper left of the notebook/Streamlit page click the "down" caret
    and choose "Create from repository"
1. Give the notebook/Streamlit a descriptive name. **Warning: dashboards and notebooks cannot
    have their name changed after the fact. Be sure to choose wisely, otherwise
    you may need to re-create it in a new branch**
1. In "File location in the repository", find the Git repository in Snowflake,
    select the branch you created above,
    and navigate to the path you want for the notebook/Streamlit in the repository.
    For instance, we might have a `notebooks` or `streamlit` subdirectory.
1. Choose the database location for the object (e.g., `ANALYTICS_DEV.PUBLIC`)
1. Choose the warehouse for the object (e.g., `REPORTING_XS_DEV`).

#### Adding an existing notebook/dashboard in Snowflake to a Git repository

!!! warning
    We currently do not recommend adding an existing Streamlit dashboard to a Git repository.
    This is because the dashboard name is a unique identifier that becomes
    the folder name in the repository. At the time of this writing, it is impossible to change this,
    which means that the folder name is both non-descriptive and doesn't work
    with a standard git-based branching workflow.

    For whatever reason, Snowflake notebooks to not have this defect: as long
    as you give the notebook a descriptive name upon creating it, the folder
    name in the git repository will match it.

1. In the left side panel for the notebook/Streamlit, click the "Connect Git Repository" button
1. In "File location in the repository", find the Git repository in Snowflake,
    select the branch you created above,
    and navigate to the path you want for the notebook/Streamlit in the repository.
    For instance, we might have a `notebooks` or `streamlit` subdirectory.
1. Add a commit message and push the commit adding the object to GitHub.
    If this is your first commit in Snowflake you will need to input your
    personal access token.

### Dev/Prod promotion

A large part of the benefit of getting notebooks and dashboards into version control
is that you can use a standard git-based branching workflow for proposing changes.
The following is a recipe for such a workflow.
We describe the workflow for a dashboard for brevity, but it should be similar for notebooks:

#### Propose a new notebook/dashboard

1. Create a new branch for the dashboard:
   `git switch -c feature-new-dashboard`
1. Enable the `REPORTER_DEV` role in Snowflake.
1. The next step is a little different for notebooks and dashboards.
    1. **If creating a dashboard:**
        Create a folder and file for the dashboard in the repository.
        *This is important because Snowflake makes it very difficult/impossible to change
        the name after the fact. Creating one with the right name at the outset gives you
        the most control, and avoids files with inscrutible timestamps or unique IDs in them!*
        ```bash
        mkdir -p streamlit/my_new_dashboard
        touch streamlit/my_new_dashboard/my_new_dashboard.py
        git commit streamlit/my_new_dashboard/my_new_dashboard.py -m "Added new file"
        git push <remote-name> feature-new-dashboard
        ```
        Connect to the blank dashboard using the "Creating a new..." workflow above.
    1. **If creating a notebook**:
        Create the new notebook in Snowflake, and add it to the git repository using the
        "Adding an existing..." workflow above.
        *Be sure to choose a good name for the notebook, as it will become the folder
        name and cannot be changed after the fact.*
1. Develop the dashboard, making regular descriptive commits.
1. When ready, create a pull request in GitHub, proposing the new dashboard
    be merged to `main`!

#### Merge the new notebook/dashboard to `main`

1. Review the dashboard code with coworkers,
    making any changes that come out of code review.
1. When satisfied, merge the pull request to `main`.
    *Snowflake seemingly cannot change the branch of a dashboard after it is created.
    Therefore you will need to recreate a production version based on the one in `main`.*
1. Enable the `REPORTER_PRD` role in Snowflake.
1. Create a new dashboard in `ANALYTICS_PRD`  based on the version in `main`,
    following the "Creating a new..." workflow.
    This version is now your production dashboard!
1. Delete the old development dashboard in Snowflake to prevent clutter.

#### Propose changes to the dashboard

Now that the dashboard is in `main`, you can propose new changes using a standard
git-based workflow.

1. Check out a new branch from `main`:
    ```bash
    git switch -c new-feature
    ```
1. Create dashboard using the "Creating a new..." workflow above.
1. Develop the dashboard, making regular descriptive commits.
1. Propose your changes in a pull request to `main`.
1. Once it is merged to main, you don't need to recreate the dashboard anymore,
    as the production version is already pointed at `main`.
    Instead, navigate to the git repository in Snowflake and click "Fetch",
    which should bring in the new changes. The next time the dashboard
    launches, it should be based on the latest version.
1. Delete the development dashboard in Snowflake to prevent clutter.

## Where to manipulate data

When developing notebooks or dashboards, the analyst often has to choose
how much data manipulation should be done in Python,
and how much should be done using SQL and dbt.
In general, we prefer to transform data and build data models using dbt,
rather than doing it within notebooks or dashboards.
This is for a few reasons:

1. dbt has a stronger version-control story than Snowflake notebooks or dashboards.
1. It's easier to test and exercise code for dbt models.
1. It's easier to reuse the data models developed in dbt for multiple applications.
1. In general, executing a Snowflake SQL query is higher-performance than bringing data into
    a Python session and manipulating it there.

That said, if you are doing highly dynamic things in a dashboard,
such as on-the-fly filtering or aggregation of data based on user interactions,
then it may make sense to do some of the transformation in the Python session.
There are no hard-and-fast rules here, and specific applications will have different tradeoffs!
But when in doubt, we recommend you prefer doing transformations in the dbt layer.
For more information about our default dbt project architecture,
see [here](/infra/architecture/).
