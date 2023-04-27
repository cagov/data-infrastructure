"""Test DAG."""
from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow.decorators import dag
from airflow.providers.amazon.aws.operators.batch import BatchOperator
from airflow.providers.amazon.aws.sensors.batch import BatchSensor

DEFAULT_ARGS = {
    "owner": "CalData",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


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
            "environment": [
                {
                    "name": "BUCKET",
                    "value": os.environ["AIRFLOW__CUSTOM__SCRATCH_BUCKET"],
                }
            ],
        },
    )
    _ = BatchSensor(
        task_id="wait_for_batch_job",
        job_id=submit_batch_job.output,
    )


run = building_footprints_dag()
