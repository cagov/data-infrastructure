"""Load building footprints to Snowflake."""
from __future__ import annotations

import os
from datetime import datetime

from common.defaults import DEFAULT_ARGS

from airflow.decorators import dag, task_group
from airflow.operators.empty import EmptyOperator
from airflow.providers.amazon.aws.operators.batch import BatchOperator
from airflow.providers.amazon.aws.sensors.batch import BatchSensor

REFERENCE_DATA = {
    "incorporated_cities": (
        "https://gis.data.ca.gov/datasets/CALFIRE-Forestry"
        "::california-incorporated-cities-1.geojson"
        "?outSR=%7B%22latestWkid%22%3A3857%2C%22wkid%22%3A102100%7D"
    ),
    "counties": (
        "https://gis.data.ca.gov/datasets/CALFIRE-Forestry"
        "::california-county-boundaries.geojson"
        "?outSR=%7B%22latestWkid%22%3A3857%2C%22wkid%22%3A102100%7D"
    ),
}


@dag(
    description="DAG for loading a variety of small geospatial datasets in a task group",
    start_date=datetime(2023, 5, 23),
    schedule_interval="@monthly",
    default_args=DEFAULT_ARGS,
    catchup=False,
)
def state_geoportal_dag():
    """State geoportal DAG."""

    # Somewhat awkward construction to avoid late-binding
    # loop variable.
    # cf. https://github.com/apache/airflow/discussions/21278
    def _make_task_group(url, name):
        @task_group(group_id=name)
        def _core_data_group():
            submit_batch_job = BatchOperator(
                task_id=f"load_{name}",
                job_name=f"california_state_geoportal_{name}",
                job_queue=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_QUEUE"],
                job_definition=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_DEFINITION"],
                overrides={
                    "command": ["python", "-m", "jobs.geo.core", url, name],
                },
                region_name="us-west-2",  # TODO: can we make this unnecessary?
            )
            _ = BatchSensor(
                task_id=f"wait_for_{name}",
                job_id=submit_batch_job.output,
                region_name="us-west-2",  # TODO: can we make this unnecessary?
            )

        return _core_data_group

    # TODO: revisit this with Airflow 2.5 to use dynamic task groups
    finalize = EmptyOperator(task_id="finalize")
    for name, url in REFERENCE_DATA.items():
        tg = _make_task_group(url, name)()
        locals()[name] = tg
        tg >> finalize


run = state_geoportal_dag()
