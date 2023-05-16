"""Load state entity budgets from ebudget site."""
from __future__ import annotations

import re
from datetime import datetime

import pandas
from common.defaults import DEFAULT_ARGS
from common.requests import get
from snowflake.connector.pandas_tools import write_pandas

from airflow.decorators import dag, task
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

PREFIX = "https://ebudget.ca.gov/budget/publication/admin"


def camel_to_snake(s: str) -> str:
    """
    Convert a camel-cased name to a snake-cased one.

    Snake-cased names are more appropriate for case-insensitive systems like
    data warehouse backends.
    """
    return re.sub(r"(?<!^)(?=[A-Z])", "_", s).lower()


@task
def crawl_ebudget_site(year="2022-23"):
    """Crawl the eBudget site for a year's budget information."""
    # This ontology doesn't match cleanly into the UCM one (Agency, subagency,
    # department, etc,  but that's okay since we treat UCM as authoritative and join
    # on the BU code. We collect and write agencies+departments differently from
    # programs because the latter have a different schema returned from the API.
    # Normalization is done in the data warehouse.
    all_agencies_and_departments = []
    all_programs = []

    agencies = get(f"{PREFIX}/e/{year}/statistics").json()
    all_agencies_and_departments.extend(agencies)

    for agency in agencies:
        print(f"Fetching department data for {agency['legalTitl']}")
        departments = get(
            f"{PREFIX}/e/{year}/statistics/{agency['webAgencyCd']}"
        ).json()
        all_agencies_and_departments.extend(departments)

        for department in departments:
            print(f"Fetching program data for {department['legalTitl']}")
            programs = get(
                f"{PREFIX}/e/{year}/orgProgram/{department['webAgencyCd']}"
            ).json()
            all_programs.extend(programs["lines"])

    agencies_df = pandas.DataFrame.from_records(all_agencies_and_departments).rename(
        columns=camel_to_snake
    )
    programs_df = pandas.DataFrame.from_records(all_programs).rename(
        columns=camel_to_snake
    )

    hook = SnowflakeHook(snowflake_conn_id="raw")
    conn = hook.get_conn()

    DB = conn.database
    SCHEMA = "STATE_ENTITIES"
    conn.cursor().execute(f"CREATE SCHEMA IF NOT EXISTS {DB}.{SCHEMA}")

    print("Loading agencies")
    write_pandas(
        conn,
        agencies_df,
        database=DB,
        schema=SCHEMA,
        table_name="EBUDGET_AGENCY_AND_DEPARTMENT_BUDGETS",
        auto_create_table=True,
        overwrite=True,
    )

    print("Loading programs")
    write_pandas(
        conn,
        programs_df,
        database=DB,
        schema=SCHEMA,
        table_name="EBUDGET_PROGRAM_BUDGETS",
        auto_create_table=True,
        overwrite=True,
    )


@dag(
    description="Load budget data from ebudget site",
    start_date=datetime(2023, 1, 17),
    schedule_interval="@monthly",
    default_args=DEFAULT_ARGS,
)
def load_ebudget_data():
    """Load eBudget data."""
    # TODO: we will likely want to grab multiple years, and also load
    # proposed and May revision data.
    crawl_ebudget_site("2022-23")


run = load_ebudget_data()
