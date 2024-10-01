## Create project git repository

Create a new git repository from the CalData Infrastructure Template
following the instructions [here](https://github.com/cagov/caldata-infrastructure-template#usage).

Once you have created the repository, push it to a remote repository in GitHub.
There are some GitHub actions that will fail because the repository is not yet
configured to work with the new Snowflake account.

## Set up CI in GitHub

The projects generated from our infrastructure template need read access to the
Snowflake account in order to do two things from GitHub actions:

1. Verify that dbt models in branches compile and pass linter checks
1. Generate dbt docs upon merge to `main`.

The terraform configurations deployed above create two service accounts
for GitHub actions, a production one for docs and a dev one for CI checks.

### Add key pairs to the GitHub service accounts

Set up key pairs for the two GitHub actions service accounts
(`GITHUB_ACTIONS_SVC_USER_DEV` and `GITHUB_ACTIONS_SVC_USER_PRD`).
This follows a similar procedure to what you did for your personal key pair,
though the project template currently does not assume an encrypted key pair.
[This bash script](https://gist.github.com/ian-r-rose/35d49bd253194f57b57e9e59a595bed8)
is a helpful shortcut for generating the key pair:
```bash
bash generate_key.sh <key-name>
```

Once you have created and set the key pairs, add them to the DSE 1Password shared vault.
Make sure to provide enough information to disambiguate the key pair from others stored in the vault,
including:

* The account locator
* The account name (distinct from the account locator)
* The service account name
* The public key
* The private key

### Set up GitHub actions secrets

You need to configure secrets in GitHub actions
in order for the service accounts to be able to connect to your Snowflake account.
From the repository page, go to "Settings", then to "Secrets and variables", then to "Actions".

Add the following repository secrets:

| Variable | Value |
|----------|-------|
| `SNOWFLAKE_ACCOUNT` | new account locator |
| `SNOWFLAKE_USER_DEV` | `GITHUB_ACTIONS_SVC_USER_DEV` |
| `SNOWFLAKE_USER_PRD` | `GITHUB_ACTIONS_SVC_USER_PRD` |
| `SNOWFLAKE_PRIVATE_KEY_DEV` | dev service account private key |
| `SNOWFLAKE_PRIVATE_KEY_PRD` | prd service account private key |

## Enable GitHub pages for the repository

The repository must have GitHub pages enabled in order for it to deploy and be viewable.

1. From the repository page, go to "Settings", then to "Pages".
1. Under "GitHub Pages visibility" select "Private" (unless the project is public!).
1. Under "Build and deployment" select "Deploy from a branch" and choose "gh-pages" as your branch.
