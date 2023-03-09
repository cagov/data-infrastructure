# CalData Terraform Infrastructure

This Terraform project

## Setup

### Installation

This project requires Terraform to run.
You might use any of a number of different package managers to install it depending on your system.

For Macs, you can use `brew`:

```bash
brew install terraform
```

Anaconda users on any archictecture should be able to use `conda` or `mamba`:

```bash
conda install -c conda-forge terraform
```

We also use `tflint` for linting, which can be installed in the same manner, e.g.:

```bash
conda install -c conda-forge tflint
```

There are a number of pre-commit checks that run on committing as well as in CI.
To install the checks, run the following from the repository root:

```bash
pre-commit install
```

You can manually run the pre-commit checks using

```bash
pre-commit run --all-files
```

### Bootstrapping remote state

When deploying a new version of your infrastrucutre, Terraform diffs the current state
against what you have specified in your infrastructure-as-code.
The current state is tracked in a JSON document,
which can be stored in any of a number of locations (including local files).

This project stores remote state using the [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3).
Before you can stand up the main infrastructure, you must first prep the remote state backend:

```bash
cd remote-state
terraform init
terraform apply
```

With the remote state infrastructure deployed, you should be able to initialize the main project.
From this directory, run:

```bash
terraform init -backend-config=./remote-state/dse-infra-dev.tfbackend
```

## Deploying Infrastructure

When you are ready to deploy a new version of the infrastructure, run

```bash
terraform apply
```

This will output the changes to the infrastructure that will be made, and prompt you for confirmation.
