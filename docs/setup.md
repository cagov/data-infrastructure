# Repository setup

## Install dependencies

### 1. Set up a Python virtual environment

Much of the software in this project is written in Python.
It is usually worthwhile to install Python packages into a virtual environment,
which allows them to be isolated from those in other projects which might have different version constraints.

One popular solution for managing Python environments is [Anaconda/Miniconda](https://docs.conda.io/en/latest/miniconda.html).
Another option is to use [`pyenv`](https://github.com/pyenv/pyenv).
Pyenv is lighter weight, but is Python-only, whereas conda allows you to install packages from other language ecosystems.

Here are instructions for setting up a Python environment using Miniconda:

1. Follow the installation instructions for installing [Miniconda](https://docs.conda.io/en/latest/miniconda.html#system-requirements).
2. Create a new environment called `infra`:
   ```bash
   conda create -n infra -c conda-forge python=3.10 poetry
   ```

   The following pronpt will appear, "_The following NEW packages will be INSTALLED:_ "
   You'll have the option to accept or reject by typing _y_ or _n_. Type _y_
3.
4. Activate the `infra` environment:
   ```bash
   conda activate infra
   ```

### 2. Install Python dependencies

Python dependencies are specified using [`poetry`](https://python-poetry.org/).

To install them, open a terminal and enter:

```bash
poetry install
```

Any time the dependencies change, you can re-run the above command to update them.

### 3. Install go dependencies

We use [Terraform](https://www.terraform.io/) to manage infrastructure.
Dependencies for Terraform (mostly in the [go ecosystem](https://go.dev/))
can be installed via a number of different package managers.

If you are running Mac OS, you can install you can install these dependencies with [Homebrew](https://brew.sh/).
First, install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install the go dependencies:

```bash
brew install terraform terraform-docs tflint go
```

If you are a conda user on any architecture, you should be able to install these dependencies with:

```bash
conda install -c conda-forge terraform go-terraform-docs tflint
```

## Configure Snowflake

In order to use Snowflake (as well as the terraform validators for the Snowflake configuration)
you should set some default local environment variables in your environment.
This will depend on your operating system and shell. For Linux and Mac OS systems,
as well as users of Windows subsystem for Linux (WSL) it's often set in
`~/.zshrc`, `~/.bashrc`, or `~/.bash_profile`.

If you use zsh or bash, open your shell configuration file, and add the lines:

```bash
export SNOWFLAKE_ACCOUNT=<account-locator>
export SNOWFLAKE_USER=<your-username>
export SNOWFLAKE_PASSWORD=<your-password>
export SNOWFLAKE_ROLE=TRANSFORMER_DEV
export SNOWFLAKE_WAREHOUSE=TRANSFORMING_DEV
```

Then open a new-terminal and verify that the environment variables are set.

## Configure AWS and GCP (optional)

### AWS

In order to create and manage AWS resources programmatically,
you need to create access keys and configure your local setup to use them:

1. [Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) the AWS command-line interface.
1. Go to the AWS IAM console and [create an access key for yourself](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey).
1. In a terminal, enter `aws configure`, and add the access key ID and secret access key when prompted. We use `us-west-2` as our default region.

### GCP

In order to run the BigQuery dbt project,
you need to authenticate with your Google account:

1. [Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) the `gcloud` command-line interface.
1. Open a terminal, and enter the following:
    ```bash
    gcloud auth application-default login \
      --scopes=https://www.googleapis.com/auth/bigquery,\
      https://www.googleapis.com/auth/drive.readonly,\
      https://www.googleapis.com/auth/iam.test
    ```
    This should open a browser window and prompt you to authenticate.

## Configure dbt

The connection information for our data warehouses will,
in general, live outside of this repository.
This is because connection information is both user-specific usually sensitive,
so should not be checked into version control.
In order to run this project locally, you will need to provide this information
in a YAML file located (by default) in `~/.dbt/profiles.yml`.

Instructions for writing a `profiles.yml` are documented
[here](https://docs.getdbt.com/docs/get-started/connection-profiles),
as well as specific instructions for
[Snowflake](https://docs.getdbt.com/reference/warehouse-setups/snowflake-setup)
and [BigQuery](https://docs.getdbt.com/reference/warehouse-setups/bigquery-setup).

You can verify that your `profiles.yml` is configured properly by running

```bash
dbt debug
```

from a project root directory (`transform` or `transform-bigquery`).

### Snowflake project

A minimal version of a `profiles.yml` for dbt development with is:

```yml
dse_snowflake:
  target: snowflake_dev
  outputs:
    snowflake_dev:
      type: snowflake
      account: <account-locator>
      user: <your-username>
      password: <your-password>
      role: TRANSFORMER_DEV
      database: TRANSFORM_DEV
      warehouse: TRANSFORMING_DEV
      schema: DBT_<your-name>   # Test schema for development
      threads: 4
```

### BigQuery project

A minimal version of a `profiles.yml` for dbt development with BigQuery is:

```yml
dse_bigquery:
  target: bigquery_dev
  outputs:
    bigquery_dev:
      type: bigquery
      method: oauth
      project: <project-id>  # Project ID to use
      dataset: dbt_<your-name>  # Test schema for development, don't use prod!
      threads: 4
```

This requires you to be authenticated using the `gcloud` CLI tool.

### Combined `profiles.yml`

You can include targets for both BigQuery and Snowflake in the same `profiles.yml`,
(as well as targets for production), allowing you to develop in several projects
using the same computer.

### Example VS Code setup

This project can be developed entirely using dbt Cloud.
That said, many people prefer to use more featureful editors,
and the code quality checks that are set up here are easier to run locally.
By equipping a text editor like VS Code with an appropriate set of extensions and configurations
we can largely replicate the dbt Cloud experience locally.
Here is one possible configuration for VS Code:

1. Install some useful extensions (this list is advisory, and non-exhaustive):
    * dbt Power User (query previews, compilation, and auto-completion)
    * Python (Microsoft's bundle of Python linters and formatters)
    * sqlfluff (SQL linter)
1. Configure the VS Code Python extension to use your virtual environment by choosing `Python: Select Interpreter` from the command palette and selecting your virtual environment from the options.
1. Associate `.sql` files with the `jinja-sql` language by going to `Code` -> `Preferences` -> `Settings` -> `Files: Associations`, per [these](https://github.com/innoverio/vscode-dbt-power-user#associate-your-sql-files-the-jinja-sql-language) instructions.
1. Test that the `vscode-dbt-power-user` extension is working by opening one of the project model `.sql` files and pressing the "▶" icon in the upper right corner. You should have query results pane open that shows a preview of the data.

## Installing `pre-commit` hooks

This project uses [pre-commit](https://pre-commit.com/) to lint, format,
and generally enforce code quality. These checks are run on every commit,
as well as in CI.

To set up your pre-commit environment locally run

```bash
pre-commit install
```

The next time you make a commit, the pre-commit hooks will run on the contents of your commit
(the first time may be a bit slow as there is some additional setup).

You can verify that the pre-commit hooks are working properly by running

```bash
pre-commit run --all-files
```
to test every file in the repository against the checks.

Some of the checks lint our dbt models and Terraform configurations,
so having the terraform dependencies installed and the dbt project configured
is a requirement to run them, even if you don't intend to use those packages.
