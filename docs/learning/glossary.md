# Modern Data Stack Glossary

This glossary is a reference for commonly used acronyms, terms, and tools associated with the modern data stack and data and analytics engineering practices.

## Acronyms

- **MDS** - Modern Data Stack
- **ETL** - Extract, Transform, Load
- **ELT** - Extract, Load, Transform
- **CI** - Continuous integration
- **CD** - Continuous delivery/deployment
- **GCS** - Google Cloud Storage
- **AWS** - Amazon Web Services
- **SaaS** - Software as a Service

## Definitions

1. **Modern data stack** - a cloud-first suite of software tools that enable data teams to connect to, process, store, transform, and visualize data.

2. **ETL vs ELT** – ETL (Extract, Transform and Load) and ELT (Extract, Load and Transform) are data integration methods that determine whether data is preprocessed before landing in storage or transformed after being stored.

    Both methods have the same three operations:

    - **Extraction**: Pulling data from its original source system (e.g. connecting to data from a SaaS platform like Google Analytics)
    - **Transformation**: Changing the data’s structure so it can be integrated into the target data system. (e.g. changing geospatial data from a JSON structure to a parquet format)
    - **Loading**: Dumping data into a storage system (e.g. AWS S3 bucket or GCS)

    Advantages of ELT over ETL:

    - **More flexibility**, as ETL is traditionally intended for relational, structured data. Cloud-based data warehouses enable ELT for structured and unstructured data
    - **Greater accessibility**, as ETL is generally supported, maintained, and governed by organizations’ IT departments. ELT allows for easier access and use by employees
    - **Scalability**, as ETL can be prohibitively resource-intensive for some businesses. ELT solutions are generally cloud-based SaaS, available to a broader range of businesses
    - **Faster load times**, as ETL typically takes longer as it uses a staging area and system. With ELT, there is only one load to the destination system
    - **Faster transformation times**, as ETL is typically slower and dependent on the size of the data set(s). ELT transformation is not dependent on data size
    - **Less time required for data maintenance**, as data may need to be re-sourced and re-loaded if the transformation is found to be inadequate for the data’s intended purposes. With ELT, the original data is intact and already loaded from disk

    Sources: *[Fivetran](https://www.fivetran.com/blog/etl-vs-elt?_gl=1*rjd374*_ga*MTAxNTU1MjM4MC4xNjc3MTkxOTcy*_ga_NE72Z5F3GB*MTY4MTMzODc0OS43LjAuMTY4MTMzODc0OS42MC4wLjA.)*, *[Snowflake](https://www.snowflake.com/guides/etl-vs-elt)*

3. **Columnar Database vs Relational Database** - a columnar database stores data by columns making it suitable for analytical query processing whereas a relational database stores data by rows making it optimized for transactional applications

    Advantages of Columnar over Relational databases:

    - Reduces amount of data needed to be loaded
    - Improves query performance by returning relevant data faster (instead of going row by row, multiple fields can be skipped)

4. **Analytics engineering** - applies software engineering practices to analytical workflows like version control and continuous integration/development. Analytics engineers are often thought of as a hybrid between data engineers and data analysts. Most analytics engineers spend their time transforming, modeling, testing, deploying, and documenting data. Data modeling – applying business logic to data to represent commonly known truths across an organization (for example, what data defines an order) – is the core of their workload and it enables analysts and other data consumers to answer their own questions.

    Originally coined two years ago, by [Michael Kaminsky](https://www.linkedin.com/in/michael-the-data-guy-kaminsky/), the term came from the ground-up, when data people experienced a shift in their job: they went from handling data engineer/scientist/analyst’s tasks to spending most of their time fixing, cleaning, and transforming data. And so, they (mainly members of the dbt community) created a terminology to describe this middle seat role: the Analytics Engineer.

    dbt comes in as a SQL-first transformation layer built for modern data warehousing and ingestion tools that centralizes data models, tests, and documentation.

    Sources: *[Castor](https://www.castordoc.com/blog/what-is-analytics-engineering)*, *[dbt](https://www.getdbt.com/what-is-analytics-engineering/)*

5. **Agile development** - is an iterative approach to software development (and project management) that helps teams ship code faster and with fewer bugs.

    - **Sprints** - a time-boxed period (usually 2 weeks) when a team works to complete a set amount of work. Some sprints have themes like if a new tool was procured an entire sprint may be dedicated to setup and onboarding.

    Additional reading: *[Atlassian: What is Agile?](https://www.atlassian.com/agile)*, *[Adobe: Project Sprints](https://business.adobe.com/blog/basics/sprints)*

6. **CI/CD** - Continuous integration and continuous delivery/deployment are automated processes to deploy code (e.g., whenever you merge to main).

    - Continuous integration (CI) automatically builds, tests, and integrates code changes within a shared repository
    - Continuous delivery (CD) automatically delivers code changes to production environments for human approval
    - ~OR ~ Continuous deployment (CD) automatically delivers and deploys code changes directly, circumventing human approval

    Source: *[Github: CI/CD explained](https://resources.github.com/ci-cd/)*

## Tools

- **[Fivetran](https://fivetran.com/docs/getting-started)** - a data loading tool that connects source data to your data warehouse.
- **[dbt](https://docs.getdbt.com/docs/introduction)** - a data transformation/modeling tool that operates as a layer on top of your data warehouse.
- **[Airflow](https://airflow.apache.org/docs/apache-airflow/stable/)** - an open-source data orchestration tool for developing, scheduling, and monitoring batch-oriented workflows.
- **[Snowflake](https://docs.snowflake.com/en/user-guide/intro-key-concepts)** - a cloud data warehouse that can automatically scale up/down compute resources to load, integrate, and analyze data.
- **[GitHub](https://github.com/features/)** - a cloud-based Git repository for version control.
- **[AWS S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)** - cloud-based object storage.
