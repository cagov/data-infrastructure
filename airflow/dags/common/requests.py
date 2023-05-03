"""Utilities for making HTTP requests."""

import backoff
import requests


@backoff.on_exception(
    backoff.expo,
    requests.exceptions.RequestException,
    max_time=30,
    max_tries=4,
)
def get(url):
    return requests.get(url)
