"""Load building footprints to Snowflake."""
from __future__ import annotations

import os
from datetime import datetime

from common.defaults import DEFAULT_ARGS

from airflow.decorators import dag
from airflow.providers.amazon.aws.operators.batch import BatchOperator
from airflow.providers.amazon.aws.sensors.batch import BatchSensor


@dag(
    description="Test DAG",
    start_date=datetime(2023, 3, 23),
    schedule_interval="@daily",
    default_args=DEFAULT_ARGS,
    catchup=False,
)
def building_footprints_dag():
    """Test DAG."""
    submit_batch_job = BatchOperator(
        task_id="submit_batch_job",
        job_name="submit_batch_job",
        job_queue=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_QUEUE"],
        job_definition=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_DEFINITION"],
        overrides={
            "command": ["python", "-m", "jobs.geo.building_footprints"],
            "environment": [
                {
                    "name": "SNOWFLAKE_ACCOUNT",
                    "value": "{{ conn.raw.extra_dejson.account }}",
                },
                {"name": "SNOWFLAKE_USER", "value": "{{ conn.raw.login }}"},
                {
                    "name": "SNOWFLAKE_DATABASE",
                    "value": "{{ conn.raw.extra_dejson.database }}",
                },
                {
                    "name": "SNOWFLAKE_WAREHOUSE",
                    "value": "{{ conn.raw.extra_dejson.warehouse }}",
                },
                {"name": "SNOWFLAKE_ROLE", "value": "{{ conn.raw.extra_dejson.role }}"},
                {
                    "name": "SNOWFLAKE_PRIVATE_KEY",
                    "value": "{{ conn.raw.extra_dejson.private_key_content }}",
                },
                {
                    "name": "SNOWFLAKE_PRIVATE_KEY_PASSPHRASE",
                    "value": "{{ conn.raw.password }}",
                },
            ],
        },
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )
    _ = BatchSensor(
        task_id="wait_for_batch_job",
        job_id=submit_batch_job.output,
    )


run = building_footprints_dag()
