"""Shared default arguments for DAGs."""
from __future__ import annotations

from datetime import timedelta
from typing import Any

from common.slack import post_to_slack_on_failure

DEFAULT_ARGS: dict[str, Any] = {
    "owner": "CalData",
    "depends_on_past": False,
    "email": ["odi-caldata-dse@innovation.ca.gov"],
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": post_to_slack_on_failure,
}
