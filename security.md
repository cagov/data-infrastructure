# CalData Security Conventions

This document describes security conventions for CalData's Data Services and Engineering team,
especially as it relates to cloud and SaaS services.

## Cloud Security and IAM

The major public clouds (AWS, GCP, Azure) all have a service for Identity and Access Management (IAM).
This allows us to manage which users or services are able to perform actions on which resources.
In general, IAM is described by:
* Users (or principals) - some person or workflow which uses IAM to access cloud resources.
* Permissions - an ability to perform some action on a resource or collection of resources.
* Policies - a group of related permissions for performing a job, which can be assigned to a role or user.
* Role - a group of policies for performing a workflow, which can be assumed by principals.

Most of the work of IAM is managing users, permissions, policies, and roles to perform tasks in a secure way.

### Principle of Least-Privilege

In general, users and roles should be assigned permissions according to the
[Principle of Least Privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege),
which states that they should have sufficient privileges to perform
legitimate work, and no more. This reduces security risks should a particular
user or role become compromised.

Both AWS and GCP have functionality for analyzing the usage history of principals,
and can flag permissions that they have but are not using.
This can be a nice way to reduce the risk surface area of a project.

### Service accounts

Service accounts are special IAM principals which act like users,
and are intended to perform actions to support a particular workflow.
For instance, a system might have a "deploy" service account in CD which is
responsible for pushing code changes to production on merge.

Some good practices around the use of service accounts
(largely drawn from [here](https://cloud.google.com/iam/docs/best-practices-service-accounts)):
* Service accounts often have greater permissions than human users, 
  so user permissions to impersonate these accounts should be monitored!
* Don't use service accounts during development (unless testing the service account permissions).
  Instead, use your own credentials in a safe development environment.
* Create single-purpose service accounts, tied to a particular application or process.
  Different applications have different security needs,
  and being able to edit or decommission accounts separately from each other is a good idea.
* Regularly rotate access keys for long-term service accounts.

### Production and Development Environments

Production environments should be treated with greater care than development ones.
In the testing and developing of a service, roles and policies are often crafted
which do not follow the principal of least privilege (i.e., they have too many permissions).

When productionizing a service or application, make sure to review the relevant
roles and service accounts to ensure they only have the necessary policies,
and that unauthorized users don't have permission to assume those roles.

### GCP practices 

GCP's [IAM documentation](https://cloud.google.com/iam/docs/how-to) is a good read,
and goes into much greater detail than this document on how to craft and maintain IAM roles.

Default GCP service accounts often have more permissions than are strictly needed
for their intended operation. For example, they might have read/write access to *all*
GCS buckets in a project, when their application only requires access to one. 

### AWS practices

AWS has a nice [user guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
for how to work with IAM, including some [best-practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html).

## Third-party SaaS Integrations

Often a third-party software-as-a-service (SaaS) provider will require service accounts
to access resources within a cloud account.
For example, `dbt` requires [fairly expansive permissions](https://docs.getdbt.com/reference/warehouse-setups/bigquery-setup#required-permissions)
within your cloud data warehouse to create, transform, and drop data.

Specific IAM roles needed for a SaaS product are usually documented in their setup guides.
These should be periodically reviewed by CalData and ODI IT-Ops staff to ensure they are still required.

## IAM through infrastructure-as-code

(TODO)

## Snowflake

(TODO)
