# Cloud Infrastructure

The DSE team [uses Terraform](../code/terraform-local-setup.md) to manage cloud infrastructure.
Our stack includes:

* An [AWS Batch](https://aws.amazon.com/batch/) environment for running arbitrary containerized jobs
* A [Managed Workflows on Apache Airflow](https://aws.amazon.com/managed-workflows-for-apache-airflow/) environment for orchestrating jobs
* A VPC and subnets for the above
* An ECR repository for hosting Docker images storing code and libraries for jobs
* A bot user for running AWS operations in GitHub Actions
* An S3 scratch bucket

## Architecture

```mermaid
flowchart TD
  subgraph AWS
    J[GitHub CD\nbot user]
    G[Artifact in S3]
    subgraph VPC
      subgraph Managed Airflow
        K1[Scheduler]
        K2[Worker]
        K3[Webserver]
      end
      F[AWS Batch Job\n on Fargate]
    end
    E[AWS ECR Docker\nRepository]
  end
  subgraph GitHub
    A[Code Repository]
  end
  E --> F
  A -- Code quality check\n GitHub action --> A
  A -- Job submission\nvia GitHub Action --> F
  A -- Docker build \nGitHub Action --> E
  A --> H[CalData\nadministrative\nuser]
  H -- Terraform -----> AWS
  K2 -- Job submission\nvia Airflow --> F
  K1 <--> K2
  K3 <--> K1
  K3 <--> K2
  F --> G
  J -- Bot Credentials --> A
```
