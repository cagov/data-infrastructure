# CalData dbt project

This is the primary dbt project for the CalData Data Services and Engineering (DSE) team.

It currently targets BigQuery as its data warehouse,
thought we will be including Snowflake in the near future.
Linting and testing are driven through GitHub actions.

## Local Development

This project can be developed entirely using dbt Cloud.
That said, many people prefer to use more featureful editors,
and the code quality checks that are set up here are easier to run locally.
These are some tips for setting up a local development environment that can
more-or-less match the dbt Cloud experience.

### Setting up your environment

First, create a Python virtual environment
(this could be a `conda` environment or a native Python one)
A local install of this repository requires:

* `dbt-core`
* `dbt-bigquery`
* `pre-commit`

A minimal setup using `conda` could be:

```bash
conda create -n dbt python=3.10  # Create a new Python 3.10 environment named `dbt`
conda activate dbt  # Activate the new environment
python -m pip install -r requirements.txt  # Install the requirements
```

### Setting up the pre-commit hooks

This project uses [pre-commit](https://pre-commit.com/) to lint, format,
and generally enforce code quality. These checks are run on every commit,
as well as in CI.

To set up your pre-commit environment locally (requires a python development environment), run

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

### Configuring the data warehouse

The connection information for our data warehouses will,
in general, live outside of this repository.
This is because connection information is both user-specific usually sensitive,
so should not be checked into version control.
In order to run this project locally, you will need to provide this information
in a YAML file located (by default) in `~/.dbt/profiles.yml`.

Specific instructions for writing a `profiles.yml` are documented
[here](https://docs.getdbt.com/docs/get-started/connection-profiles)
and [here](https://docs.getdbt.com/reference/warehouse-setups/bigquery-setup).

A minimal version of a `profiles.yml` for BigQuery is:

```yml
default:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: <project-id>  # Project ID to use
      dataset: dbt_<your-name>  # Test schema for development, don't use prod!
      threads: 4
```

You can verify that your `profiles.yml` is configured properly by running

```bash
dbt debug
```

from the project root directory.

### Example VS Code setup

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

### Building the docs

To build and view the docs locally, run

```bash
(dbt docs generate && cd target/ && python -m http.server)
```

in a terminal, then navigate to `http://localhost:8000` in your web browser.


## Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [dbt community](http://community.getbdt.com/) to learn from other analytics engineers
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
