# CalData dbt project

This is the primary dbt project for the CalData Data Services and Engineering (DSE) team.
It targets Snowflake as its data warehouse.
Linting and testing are driven through GitHub actions.

## Building the docs

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
