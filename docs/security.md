# CalData Security Conventions

This document describes security conventions for CalData's Data Services and Engineering team,
especially as it relates to cloud and SaaS services.

## Cloud Security and IAM

The major public clouds (AWS, GCP, Azure) all have a service for Identity and Access Management (IAM).
This allows us to manage which users or services are able to perform actions on which resources.
In general, IAM is described by:

* **Users** (or principals) - some person or workflow which uses IAM to access cloud resources. Users can be assigned to **groups**.
* **Permissions** - an ability to perform some action on a resource or collection of resources.
* **Groups** - Rather than assigning permissions directly to users, it is considered good practice to instead create user **groups** with appropriate permissions, then add users to the group. This makes it easier to add and remove users while maintaining separate user personas.
* **Policies** - a group of related **permissions** for performing a job, which can be assigned to a **role** or **user**.
* **Role** - a group of policies for performing a workflow. Roles are similar to **users**, but do not have a user identity associated with them. Instead, they can be assumed by users or services to perform the relevant workflow.

Most of the work of IAM is managing users, permissions, groups, policies, and roles to perform tasks in a secure way.

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

### Fivetran practices

Fivetran's [security docs](https://fivetran.com/docs/security) which link to a deeper dive white paper are a good place to go to understand their standards and policies for connecting, replicating, and loading data from all of our data sources.

Within the ***Users & Permissions*** section of our Fivetran account there are three sub-sections for: *Users*, *Roles*, and *Teams*.

Fivetran also provides [detailed docs on Role-Based Access Controls (RBAC)](https://fivetran.com/docs/getting-started/fivetran-dashboard/account-management/role-based-access-control) which covers the relationship among users, roles, and teams when defining RBAC policies.

This diagram from their docs gives an at-a-glance view of how RBAC could be configured across multiple teams, destinations, and connectors. Since we aren't a massive team, we may not have as much delegation, but this gives you a sense of what's possible.

![Diagram showing an approach to delegating access down from account to destinations to sources in Fivetran](https://fivetran.com/static-assets-docs/static/admin-teams-connectors.cbaa03b2.png)
[See diagram in context of docs](https://fivetran.com/docs/getting-started/fivetran-dashboard/account-management/role-based-access-control#newrbacmodelbenefits).

**Note:** With the recent creation of organizations in Fivetran, client project security policies get simplified as we can isolate them from our other projects by creating a separate account. This is also better from a handoff perspective.
The [*Roles* page](https://fivetran.com/dashboard/account/users-permissions/roles) defines all default role types and how many users are associated with each type. There is also the ability to create custom roles via the *+ Add Role* button.

Currently, we have two teams:
- IT
- Data Services and Engineering (DSE)

Our IT team's role is **Account Billing and User Access**. This is a custom role that provides billing and user management access with view-only access for the remaining account-level features; it provides no destination or connector access.


The DSE team both manages CalData projects and onboards clients into Fivetran, and so its members have Account Administrator roles.

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

## Security Review Standard Practices

(TODO, possibly pulling from [Agile Application Security](https://www.amazon.com/Agile-Application-Security-Enabling-Continuous/dp/1491938846/ref=cm_cr_arp_d_product_top))
