"""
Python script to run airflow CLI commands in a MWAA environment.

Adapted from sample code here:
https://docs.aws.amazon.com/mwaa/latest/userguide/airflow-cli-command-reference.html#airflow-cli-command-examples
"""
import base64
import sys

import boto3
import requests

mwaa_env_name = "dse-infra-dev-us-west-2-mwaa-environment"

client = boto3.client("mwaa")

mwaa_cli_token = client.create_cli_token(Name=mwaa_env_name)

mwaa_auth_token = "Bearer " + mwaa_cli_token["CliToken"]
mwaa_webserver_hostname = f"https://{mwaa_cli_token['WebServerHostname']}/aws_mwaa/cli"
raw_data = " ".join(sys.argv[1:])

mwaa_response = requests.post(
    mwaa_webserver_hostname,
    headers={"Authorization": mwaa_auth_token, "Content-Type": "text/plain"},
    data=raw_data,
)

mwaa_std_err_message = base64.b64decode(mwaa_response.json()["stderr"]).decode("utf8")
mwaa_std_out_message = base64.b64decode(mwaa_response.json()["stdout"]).decode("utf8")

print(mwaa_response.status_code)
print(mwaa_std_err_message)
print(mwaa_std_out_message)
