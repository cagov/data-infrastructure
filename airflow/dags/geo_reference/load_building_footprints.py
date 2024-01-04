"""Load building footprints to Snowflake."""
from __future__ import annotations

import os
from datetime import datetime

from common.defaults import DEFAULT_ARGS

from airflow.decorators import dag
from airflow.providers.amazon.aws.operators.batch import BatchOperator
from airflow.providers.amazon.aws.sensors.batch import BatchSensor


def _construct_batch_args(name: str, command: list[str]) -> dict:
    return {
        "task_id": name,
        "job_name": name,
        "job_queue": os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_QUEUE"],
        "job_definition": os.environ["AIRFLOW__CUSTOM__DEFAULT_JOB_DEFINITION"],
        "overrides": {
            "command": command,
            "resourceRequirements": [
                {"type": "VCPU", "value": "8"},
                {"type": "MEMORY", "value": "32768"},
            ],
        },
        "region_name": "us-west-2",  # TODO: can we make this unnecessary?
    }


@dag(
    description="Test DAG",
    start_date=datetime(2023, 5, 23),
    schedule_interval="@monthly",
    default_args=DEFAULT_ARGS,
    catchup=False,
)
def building_footprints_dag():
    """DAG for loading MS Building footprints dataset."""
    load_us_footprints = BatchOperator(
        **_construct_batch_args(
            name="load_us_building_footprints",
            command=["python", "-m", "jobs.geo.load_us_building_footprints"],
        )
    )
    wait_for_us_footprints_load = BatchSensor(
        task_id="wait_for_us_footprints_load",
        job_id=load_us_footprints.output,
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )

    unload_us_footprints = BatchOperator(
        **_construct_batch_args(
            name="unload_us_building_footprints",
            command=["python", "-m", "jobs.geo.write_building_footprints", "us"],
        )
    )
    _ = BatchSensor(
        task_id="wait_for_us_footprints_unload",
        job_id=unload_us_footprints.output,
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )

    unload_us_footprints.set_upstream(wait_for_us_footprints_load)

    load_global_ml_footprints = BatchOperator(
        **_construct_batch_args(
            name="load_global_ml_building_footprints",
            command=["python", "-m", "jobs.geo.load_global_ml_building_footprints"],
        )
    )
    wait_for_global_ml_footprints_unload = BatchSensor(
        task_id="wait_for_global_ml_footprints_load",
        job_id=load_global_ml_footprints.output,
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )

    unload_global_ml_footprints = BatchOperator(
        **_construct_batch_args(
            name="unload_global_ml_building_footprints",
            command=["python", "-m", "jobs.geo.write_building_footprints", "global_ml"],
        )
    )
    _ = BatchSensor(
        task_id="wait_for_global_ml_footprints_unload",
        job_id=unload_global_ml_footprints.output,
        region_name="us-west-2",  # TODO: can we make this unnecessary?
    )

    unload_global_ml_footprints.set_upstream(wait_for_global_ml_footprints_unload)


run = building_footprints_dag()
