"""DAG to load synthetic test data into SQL Server instances (RDS and Azure SQL).

This DAG creates a simple schema with users and transactions tables (if they don't
exist), then appends semi-realistic test data using the Faker library. Each run
generates fresh data with unique values. It runs in two parallel branches:
one for AWS RDS SQL Server and one for Azure SQL Database.

The data generation logic is in common/test_data_generator.py for reusability.
Tasks are dynamically generated to avoid code duplication between instances.
"""

from datetime import datetime
from typing import Dict, Any
import mssql_python
from airflow.decorators import dag, task
from common.defaults import DEFAULT_ARGS
from common.test_data_generator import (
    create_schema,
    generate_users,
    generate_transactions,
    bulk_insert_users,
    bulk_insert_transactions,
    verify_data_integrity,
)


# Instance configurations
INSTANCES = {
    "rds": {
        "conn_id": "rds_sqlserver",
        "use_database": "synthetic_data",  # RDS needs explicit USE statement
        "create_database": True,  # RDS: create synthetic_data database
    },
    "azure": {
        "conn_id": "azure_sql_dev",
        "use_database": None,  # Azure connection includes database in connection string
        "create_database": False,  # Azure: database already exists
    },
}


# SQL to create database (RDS only)
CREATE_DATABASE_SQL = """
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'synthetic_data')
BEGIN
    CREATE DATABASE synthetic_data;
END
"""


def get_connection_string(conn_id: str) -> str:
    """Build mssql-python connection string from Airflow connection."""
    from airflow.hooks.base import BaseHook

    conn = BaseHook.get_connection(conn_id)
    extra = conn.extra_dejson

    # Build connection string for mssql-python
    conn_str = (
        f"SERVER=tcp:{conn.host},{conn.port or 1433};"
        f"DATABASE={conn.schema};"
        f"UID={conn.login};"
        f"PWD={conn.password};"
        f"Authentication={extra.get('Authentication', 'ActiveDirectoryServicePrincipal')};"
        f"Encrypt={extra.get('Encrypt', 'yes')};"
        f"TrustServerCertificate={extra.get('TrustServerCertificate', 'yes')};"
    )
    return conn_str


def make_create_database_task(instance_key: str, instance_config: Dict[str, Any]):
    """Factory function to create a database creation task (RDS only)."""

    @task(task_id=f"create_database_{instance_key}")
    def create_database_task():
        """Create database if it doesn't exist."""
        conn_str = get_connection_string(instance_config["conn_id"])
        conn = mssql_python.connect(conn_str)
        cursor = conn.cursor()

        try:
            cursor.execute(CREATE_DATABASE_SQL)
            conn.commit()
        finally:
            cursor.close()
            conn.close()

    return create_database_task


def make_create_schema_task(instance_key: str, instance_config: Dict[str, Any]):
    """Factory function to create a schema creation task for a specific instance."""

    @task(task_id=f"create_schema_{instance_key}")
    def create_schema_task():
        """Create test data schema (users and transactions tables)."""
        conn_str = get_connection_string(instance_config["conn_id"])
        conn = mssql_python.connect(conn_str)
        cursor = conn.cursor()

        try:
            if instance_config["use_database"]:
                cursor.execute(f"USE {instance_config['use_database']}")

            create_schema(cursor)
        finally:
            cursor.close()
            conn.close()

    return create_schema_task


def make_load_users_task(instance_key: str, instance_config: Dict[str, Any]):
    """Factory function to create a load_users task for a specific instance."""

    @task(task_id=f"load_users_{instance_key}")
    def load_users(num_users: int = 1000):
        """Load users to SQL Server instance."""
        conn_str = get_connection_string(instance_config["conn_id"])
        conn = mssql_python.connect(conn_str)
        cursor = conn.cursor()

        try:
            if instance_config["use_database"]:
                cursor.execute(f"USE {instance_config['use_database']}")

            users = generate_users(num_users=num_users)
            count = bulk_insert_users(cursor, users)
            return count
        finally:
            cursor.close()
            conn.close()

    return load_users


def make_load_transactions_task(instance_key: str, instance_config: Dict[str, Any]):
    """Factory function to create a load_transactions task for a specific instance."""

    @task(task_id=f"load_transactions_{instance_key}")
    def load_transactions(transactions_per_user: int = 5):
        """Load transactions to SQL Server instance."""
        conn_str = get_connection_string(instance_config["conn_id"])
        conn = mssql_python.connect(conn_str)
        cursor = conn.cursor()

        try:
            if instance_config["use_database"]:
                cursor.execute(f"USE {instance_config['use_database']}")

            cursor.execute("SELECT id FROM dbo.users")
            user_ids = [row[0] for row in cursor.fetchall()]

            if not user_ids:
                raise ValueError("No users found! Load users first.")

            transactions = generate_transactions(user_ids, transactions_per_user)
            count = bulk_insert_transactions(cursor, transactions)
            return count
        finally:
            cursor.close()
            conn.close()

    return load_transactions


def make_verify_task(instance_key: str, instance_config: Dict[str, Any]):
    """Factory function to create a verify task for a specific instance."""

    @task(task_id=f"verify_data_{instance_key}")
    def verify_data():
        """Verify SQL Server data integrity and compute statistics."""
        conn_str = get_connection_string(instance_config["conn_id"])
        conn = mssql_python.connect(conn_str)
        cursor = conn.cursor()

        try:
            if instance_config["use_database"]:
                cursor.execute(f"USE {instance_config['use_database']}")

            results = verify_data_integrity(cursor)
            return results
        finally:
            cursor.close()
            conn.close()

    return verify_data


@dag(
    description="Append synthetic test data to SQL Server instances (RDS and Azure SQL)",
    start_date=datetime(2026, 2, 1),
    schedule_interval="@daily",
    default_args=DEFAULT_ARGS,
    catchup=False,
    tags=["sqlserver", "test-data", "opex"],
)
def load_sqlserver_test_data():
    """Load test data into both RDS and Azure SQL Server instances."""

    # Dynamically create tasks for each instance
    for instance_key, instance_config in INSTANCES.items():
        # Create database if needed (RDS only)
        if instance_config["create_database"]:
            create_db = make_create_database_task(instance_key, instance_config)()
        else:
            create_db = None

        # Create tasks using factory functions
        create_schema_task = make_create_schema_task(instance_key, instance_config)()
        load_users = make_load_users_task(instance_key, instance_config)()
        load_transactions = make_load_transactions_task(instance_key, instance_config)()
        verify = make_verify_task(instance_key, instance_config)()

        # Set up dependencies
        if create_db:
            create_db >> create_schema_task >> load_users >> load_transactions >> verify
        else:
            create_schema_task >> load_users >> load_transactions >> verify


# Instantiate the DAG
load_sqlserver_test_data_dag = load_sqlserver_test_data()
