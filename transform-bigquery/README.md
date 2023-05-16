# CalData dbt project

This is the BigQuery dbt project for the CalData Data Services and Engineering (DSE) team.
Most of our data is in the [Snowflake dbt project](../transform), but some Google-specific
data pipelines are conveniently kept in GCP.
Linting and testing are driven through GitHub actions.

## Building the docs

To build and view the docs locally, run

```bash
(dbt docs generate && cd target/ && python -m http.server)
```

in a terminal, then navigate to `http://localhost:8000` in your web browser.
