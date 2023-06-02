# MDSA Training

This details a possible training path for participants in the Modern Data Stack Accelerator.
Not all participants necessarily need every module in the path,
but data engineers and data analysts should ensure that they are familiar with the content here.

## GitHub

**Goals of training**

* Become familiar with a branching style of code development.
* Become familiar with GitHub's user interface for issues, pull requests, code review, and continuous integration.

**Who should go through this?** Data engineers and data analysts in the MDSA project will do a lot of work in GitHub.
Non-coding project participants should also become familiar with GitHub's user interface,
and have a understanding of how to write issues and use Markdown.

### 1. Set up a GitHub account

If you already have an account, great!
If not, go ahead and set one up by going to [GitHub's pricing page](https://github.com/pricing)
and selecting the option for a free account. Then:

1. Enter a username
1. Enter your email (we suggest work email, you can associate other emails later if you like)
1. Enter a password
1. Verify that you're human by solving a puzzle
1. Click create account
1. An email will be sent to you for verification. Verify your email following those instructions

You'll use this account or one you already have to participate in the modern data stack accelerator.

### 3. Read GitHub's [guide to git](https://github.com/git-guides/)

This is a good introduction to the mechanics of git (separate from GitHub as a code hosting platform).
A large amount of development happens locally on your machine,
and being fluent with concepts like cloning, pushing, pulling, and committing
will make everything that follows much easier.

### 3. Go through the [introduction to GitHub tutorial](https://github.com/skills/introduction-to-github).

This should take about an hour, and should be taken by all data engineers and data analysts on the project.
You will learn how to create a branch, commit a change, open a pull request, and merge your change.

### 4. Learn how to [author GitHub-flavored Markdown](https://github.com/skills/communicate-using-markdown)

This should take about an hour, and involves no code.
It is useful for many project members to learn this material,
including those who are not doing day-to-day coding,
as it is used in issue tracking, cross referencing, and other project-management tooling.

### 5. Learn how to [review pull requests on GitHub](https://github.com/skills/review-pull-requests)

This should take about an hour, and should be taken by all data engineers and data analysts on the project.
You will learn how to open pull requests, review them, suggest changes, and merge them.
Any change to the project codebase should go through this process,
as it allows for peer review, automated checks and tests (CI), and automated deployments (CD).

## Snowflake

**Goals of training**

* Understand what Snowflake is, and how cloud data warehouses differ from traditional on-prem OLTP databases.
* Become familiar with Snowflake terminology (warehouse, database, role etc).
* Have a basic understanding of how to use the Snowflake user interface.

**Who should go through this?**
Data engineers should go through this training,

### 1. Take Snowflake's [Data Warehousing Workshop](https://learn.snowflake.com/en/courses/uni-essdww101/)

This covers the fundamentals of the Snowflake Data Warehouse.
It should take 6-8 hours. Below are notes we compiled after recently completing the training.

**Always check your ROLE and WAREHOUSE at the top right**. For the training there is only one warehouse and you will only switch between two roles, ACCOUNTADMIN and SYSADMIN. There may be one exercise in the very beginning where they ask you to switch between all the roles just to see what changes.

**Always check your Worksheet Context settings**, what database and schema are you working with? If it’s not the right one switch it, you can also force these settings in your worksheet by writing the following code:

```sql
use database DEMO_DB;
use schema PUBLIC;
use role ACCOUNTADMIN;
use warehouse COMPUTE_WH;
```

Objects in Snowflake are as follows and in no particular order:

| Tables | Functions | Sequences |
| Stages | Databases | File formats |

**All of these objects, including ones not listed have ownership**, so the *ROLE* you use to create them will be the role that owns it. Most objects during the training will be created with *SYSADMIN*.

If you accidentally select a role other than that or *ACCOUNTADMIN* to create an object do not fret! You have two options. Switch to the role that created the object and transfer ownership to the right role, delete and recreate the object with the right role

**Object Pickers**, as mentioned in *Lesson 3: Data Commands* in the *Running SHOW Commands* section are a part of the UI – when you literally use your mouse or trackpad to select one of the objects listed above or another you are using “Object picker”. The Snowsight UI is rapidly evolving so there will be differences between the UI in the training gifs, videos, and screenshots and the UI you are logged in to. Rest assured that you can 100% get through the training despite these differences. Elements that are referenced, while spatially and visually different between UIs, are still there and intuitive to find. Concepts mentioned still hold true. Trust yourself and your ability to find things.

In later lessons when you are asked to load data or copy into a table you will use this code:

```sql
FROM @garden_plants.veggies.like_a_window_into_an_s3_bucket/file_name.file_type;
```

Replace *file_name* and *file_type*, e.g. *my_cool_file.csv*

### 2. Tour your Snowflake account

The Snowflake account for your project should have already been created.
Review the [architecture](../snowflake.md) of the account.
In particular, make sure you have an understanding of

* The different databases (`RAW`, `TRANSFORM`, `ANALYTICS`)
* The different functional roles, and how they map onto the databases.
* Which roles to assume depending upon what kind of work you are doing.

## dbt

**Goals of training**

* Become familiar with building data models in dbt
* Learn how to go through a GitHub based branching workflow with dbt

**Who should go through this?**
Data engineers and data analysts should go through this training,
as it represents the core workflow for transforming raw datasets into reporting-ready models.


### 1. Take the [dbt fundamentals](https://courses.getdbt.com/courses/fundamentals) course.

This course is intended to give you an overview of what "analytics engineering" means
in a dbt context, and how to build models using the dbt Cloud user interface.

You will be able to to follow along with the course using CalData's dbt Cloud account
as well as the project Snowflake account.
There are a few differences between CalData's environment and that assumed by the course to be aware of:

1. **Database names**: In the course there are two databases, `raw` and `analytics`.
    In the project Snowflake account we have both development and production databases,
    which are suffixed with `dev` and `prd`, respectively. As you are taking the course,
    you will need to substitute the suffixed form of the names (e.g., where you see `raw`, use `raw_dev`).
1. **Development credentials**: When setting up dbt Cloud you will need to give it your
    development credentials. These will be the same as what's described in [these docs](../snowflake.md#snowflake-project):
    * **Account**: `<your-account-locator>`
    * **Role**: `TRANSFORMER_DEV`
    * **Database**: `TRANSFORM_DEV`
    * **Warehouse**: `TRANSFORMING_DEV`
    * **Auth method**: Choose "Username and Password" for now.
    * **Username**: `<your-username>`
    * **Password**: `<your-password>`
    * **Schema**: `DBT_<your-name>`
    * **Target Name**: The profile listed in `transform/dbt_project.yml`
1. **Project setup**: During the "Set up dbt Cloud" portion of the course,
    it will direct you to a separate [Loading data into Snowflake](https://docs.getdbt.com/docs/get-started/getting-started/getting-set-up/setting-up-snowflake#load-data)
    quickstart. You will be able to skip much of the setup as the project should already be configured.
    Start with step 7: "Build your first model".

### 2. Go through a pull request cycle in GitHub

Once you are done with the dbt fundamentals course, you should have a series of
data models, tests, and documentation for your code.
Open a pull request on GitHub with this new code.
If you are going through this training path with others,
review each other's pull requests, discuss any differences,
correct any errors, and merge them.

Congratulations! The above represents the analytics engineering workflow,
where you took raw data in Snowflake, created some derived data models using dbt,
and reviewed and merged your changes using GitHub.
