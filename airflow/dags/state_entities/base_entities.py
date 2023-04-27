"""Load state entities list from department of finance."""
from __future__ import annotations

import io
import re
from datetime import datetime

import pandas
import requests
from common.defaults import DEFAULT_ARGS
from snowflake.connector.pandas_tools import write_pandas

from airflow.decorators import dag, task
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

GBQ_DATASET = "state_entities"
LEVEL_LABELS = ["A", "B", "1", "2", "3"]
DATA_URL = (
    "https://dof.ca.gov/wp-content/uploads/sites/352/Accounting/"
    "Policies_and_Procedures/Uniform_Codes_Manual/3orgstruc.pdf"
)


def clean_name(name: str) -> str:
    """Strip leading/trailing whitespace and replace repeated spaces with single spaces."""
    return re.sub(" {2,}", " ", name.strip())


@task
def load_data() -> None:
    """### Load Department of Finance State Entities data."""
    import pdfplumber

    hook = SnowflakeHook(snowflake_conn_id="raw")
    conn = hook.get_conn()

    # Regexes matching frontmatter and other lines we should skip
    skip = [
        # Just white space
        r"^\s*$",
        # Header material
        r"REVISED(\s+)(\w+)(\s+)(\d+)",
        r"(\s*)DEPARTMENT(\s+)OF(\s+)FINANCE(\s*)",
        r"(\s*)UNIFORM(\s+)CODES(\s+)MANUAL(\s*)",
        r"(\s*)ORGANIZATION(\s+)CODES(\s*)",
        r"(\s*)BY(\s+)STRUCTURE(\s*)",
        # Column headers
        r"(\s*)A(_+)(\s+)B(_+)(\s+)1(_+)(\s*)",
        # Page number
        r"^(\s*)(\d+)(\s*)$",
    ]

    skip_re = re.compile("|".join(skip), flags=re.IGNORECASE)
    entity_re = re.compile(r"^( *)(\d+)\s+(.+)$")

    r = requests.get(DATA_URL)
    f = io.BytesIO(r.content)
    pdf = pdfplumber.open(f)  # type: ignore

    levels: list[str | None] = [
        None,
    ] * len(LEVEL_LABELS)
    indent = None
    ts = 5
    entities: list[tuple[str | None, ...]] = []

    for page in pdf.pages:
        lines = page.extract_text(layout=True).split("\n")
        print(page)
        for line in lines:
            if skip_re.search(line):
                continue

            match = entity_re.match(line)
            if match is None:
                print(
                    f'Unable to parse line "{clean_name(line)}", assigning to previous name'
                )
                revised = list(entities[-1])
                revised[-1] = revised[5] + " " + clean_name(line)  # type: ignore
                entities[-1] = tuple(revised)
                continue

            # Get the raw matches
            spaces, code, name = match.groups()

            # Set the top-level indentation
            if indent is None:
                indent = len(spaces)

            # Strip excess whitespace from the name
            name = clean_name(name)

            # Get the level number from the whitespace 😬
            level_n = (len(spaces) - indent) // ts
            assert level_n <= len(LEVEL_LABELS) - 1

            # Fill the levels, null out everything after the current level
            levels[level_n] = code
            levels[level_n + 1 :] = [None] * (len(LEVEL_LABELS) - level_n - 1)

            entities.append((*levels, name))

    df = (
        pandas.DataFrame.from_records(entities, columns=[*LEVEL_LABELS, "name"])
        .astype("string[python]")  # type: ignore
        .rename(columns={"1": "L1", "2": "L2", "3": "L3"})
    )
    write_pandas(
        conn,
        df,
        database="RAW",
        schema="STATE_ENTITIES",
        table_name="BASE_ENTITIES",
        auto_create_table=True,
    )


@dag(
    description="Load department of finance state entities list",
    start_date=datetime(2022, 12, 19),
    schedule_interval="@monthly",
    default_args=DEFAULT_ARGS,
    catchup=False,
)
def load_department_of_finance_state_entities():
    load_data()


run = load_department_of_finance_state_entities()
