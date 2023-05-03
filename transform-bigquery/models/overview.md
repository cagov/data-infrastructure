{% docs __overview__ %}

# CalData dbt Documentation

Welcome to the CalData Data Services and Engineering `dbt` BigQuery docs.
To go back to the top-level docs, follow [this link](../)

## Navigation

You can use the `Project` and `Database` navigation tabs on the left side of the window to explore the models in your project.

### Project Tab

The Project tab mirrors the directory structure of your dbt project.
In this tab, you can see all of the models defined in your dbt project, as well as models imported from dbt packages.

### Database Tab

The Database tab also exposes your models, but in a format that looks more like a database explorer.
This view shows relations (tables and views) grouped into database schemas.
Note that ephemeral models are not shown in this interface, as they do not exist in the database.

## Graph Exploration

You can click the blue icon on the bottom-right corner of the page to view the lineage graph of your models.

On model pages, you'll see the immediate parents and children of the model you're exploring.
By clicking the Expand button at the top-right of this lineage pane,
you'll be able to see all of the models that are used to build, or are built from,
the model you're exploring.

Once expanded, you'll be able to use the `--select` and `--exclude` model selection syntax to filter the models in the graph.
For more information on model selection, check out the [dbt docs](https://docs.getdbt.com/reference/node-selection/syntax).

Note that you can also right-click on models to interactively filter and explore the graph.

{% enddocs %}
