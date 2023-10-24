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
    start_date=datetime(2023, 5, 23),
    schedule_interval="@monthly",
    default_args=DEFAULT_ARGS,
    catchup=False,
)
def building_footprints_dag():
    """DAG for loading MS Building footprints dataset."""
    submit_batch_job_us = BatchOperator(
        task_id="load_us_footprints",
        job_name="us_building_footprints",
        job_queue=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_QUEUE"],
        job_definition=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_DEFINITION"],
        overrides={
            "command": ["python", "-m", "jobs.geo.load_us_building_footprints"],
            "resourceRequirements": [
                {"type": "VCPU", "value": "8"},
                {"type": "MEMORY", "value": "32768"},
            ],
        },
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )
    _ = BatchSensor(
        task_id="wait_for_batch_job_us",
        job_id=submit_batch_job_us.output,
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )

    submit_batch_job_global_ml = BatchOperator(
        task_id="load_global_ml_footprints",
        job_name="global_ml_building_footprints",
        job_queue=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_QUEUE"],
        job_definition=os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_DEFINITION"],
        overrides={
            "command": ["python", "-m", "jobs.geo.load_global_ml_building_footprints"],
            "resourceRequirements": [
                {"type": "VCPU", "value": "8"},
                {"type": "MEMORY", "value": "32768"},
            ],
        },
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )
    __ = BatchSensor(
        task_id="wait_for_batch_job_global_ml",
        job_id=submit_batch_job_global_ml.output,
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )


run = building_footprints_dag()
