# Data Services and Engineering Standards

## Cloud Server/DB/Project (e.g. Google Project Id)

### Naming Conventions 

Cloud Naming Convention | stepan.wtf 

[prefix]\_[projectname]\_[env]\_[resource]\_[location]\_[description]\_[suffix]

| **Component** | **Description** | **Req.** | **Constraints** |
| ------------- | ------------- | ------------- | ------------- |
**env** | data status type | ✔ | len 3, fixed
**project** | project name | ✔ | len 4-10, a-z0-9
**description** | additional description | ✗ | len 1-20, a-z0-9
**suffix** | random suffix | ✗ | len 4, a-z0-9


Principles
- As short as possible, but still human readable

### BigQuery
- **Project name constraints**: The name has invalid characters. Enter letters, numbers, single quotes, hyphens, spaces or exclamation points.
- **Project ID** constraints: Project ID can have lowercase letters, digits, or hyphens. It must start with a lowercase letter and end with a letter or number.
- Cannot change dataset names, see [here](https://stackoverflow.com/questions/22692905/rename-datasets-in-bigquery)

#### DSE - Product Analytics

- **Project name**: [DSE Product Analytics](https://console.cloud.google.com/welcome?project=dse-product-analytics-prd-bqd)
- **Project ID**: dse-product-analytics-prd-bqd
- **Sources**: GA4, GSC, Benefits rec widget data
- **Datasets**
   - _prd_benefitsrecwidget_research_
   - _analytics_314711183_
   - _analytics_322878501_
   - _ex: stg_ga4_statewide_322878501_
   - _ex: stg_ga4_innovation_326878242_

- Considerations: 
   - ODI-built products versus paid products e.g. page feedback vs. survey monkey - may have security implication
   - Potential new dataset to adhere to naming conventions and to union historical data not captured when we did the initial GA4 <> BQ link (may be able to use Fivetran to do the incremental loading to avoid data sampling mentioned below)
   - dbt scratch datasets are created with prefix dbt_<first name initial><last name> e.g. dbt_irose 

Notes from Shail @ Google:

_The BQ linking on GA4 would get the raw data from that point onwards._
 
_For historical data, we can use APIs, which only can give us the sample data that we see on the GA4 console._
 
_Also, GA4 admins would have access to view the property change history that provides a log of all events that happened_
 
_The limit is 10B hits or 13 months, which is about as long as GA keeps data. https://support.google.com/analytics/answer/3416092?hl=en#zippy=%2Cin-this-article._ 
 
_Be sure to select 'never delete' when you import if you want BQ to keep longer than GA keeps or set 'data exp' to 'never'._

#### DSE - Reference Data

- **Project name**: [DSE Reference Data](https://console.cloud.google.com/welcome?project=dse-reference-data-prd-bqd)
- **Project id**: dse-reference-data-prd-bqd
- **Sources**: Geo, income, R/E, Dept list
- **Considerations**:
- **Datasets**
   - ex: prd_censusACS_2020
   - ex: prd_censusDEC_2020

### FiveTran

**Destination name constraints**: Destination names must start with a letter or underscore and only contain letters, numbers or underscores
**Connector name**: Appears in your destination and cannot be changed after you test the connector or save the form for later.

- **Destination name**: DSE_Product_Analytics
- **Connector name**: prd_benefitsRecWidget_research

**Considerations/Things to know:**
- Destination names should map to BQ project names replacing spaces with underscores
- Connector names should map to BQ dataset names
- BigQuery connector checks:
   - We are not using our own Service Account
   - We are not using our GCS bucket to process data, instead we are using a Fivetran-managed bucket.
   - We are not shifting UTC offset with daylight savings time

### dbt

- Project name: DSE Product Analytics
- Repo: git://github.com/cagov/data-dbt-core.git
- In BQ scratch datasets are created with prefix dbt_<first name initial><last name> e.g. dbt_irose 

**Considerations**:
- dbt project names should map to BQ project names

## Warehouse
Naming Conventions
https://blog.panoply.io/data-warehouse-naming-conventions 
https://docs.getdbt.com/blog/stakeholder-friendly-model-names 
https://docs.getdbt.com/blog/on-the-importance-of-naming 

## Cloud Storage
https://cloud.google.com/storage/docs/naming-buckets 
https://hadoopjournal.wordpress.com/2020/09/04/google-cloud-storage-best-practices/ 

Resources
- [How we structure our dbt project](https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview)
- [BigQuery Security Guide](https://cloud.google.com/bigquery/docs/data-governance)
- [Principle of Least Privilege](https://cloud.google.com/blog/products/identity-security/dont-get-pwned-practicing-the-principle-of-least-privilege) 
- [Data Governance Summary](https://cloud.google.com/bigquery/docs/data-governance-summary)
- [General Security Best Practices in BigQuery](https://towardsdatascience.com/6-best-practices-for-managing-data-access-to-bigquery-4396b0a3cfba)
- https://airbyte.com/blog/best-practices-dbt-style-guide