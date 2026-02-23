"""DAG to load synthetic test data into SQL Server instances (RDS and Azure SQL).

This DAG creates a simple schema with users and transactions tables, then loads
semi-realistic test data using the Faker library. It runs in two parallel branches:
one for AWS RDS SQL Server and one for Azure SQL Database.

The data generation logic is in common/test_data_generator.py for reusability.
Tasks are dynamically generated to avoid code duplication between instances.
"""

from datetime import datetime
from typing import Dict, Any
from airflow.decorators import dag, task
from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
from airflow.providers.microsoft.mssql.operators.mssql import MsSqlOperator
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
        "create_database": True,  # RDS: create synthetic_data database (connects to master first)
    },
    "azure": {
        "conn_id": "azure_sql_dev",
        "use_database": None,  # Azure connection includes database in connection string
        "create_database": False,  # Azure: database already exists, can't CREATE from user connection
    },
}


# SQL to create database (RDS only)
CREATE_DATABASE_SQL = """
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'synthetic_data')
BEGIN
    CREATE DATABASE synthetic_data;
END
"""


def make_create_schema_task(instance_key: str, instance_config: Dict[str, Any]):
    """Factory function to create a schema creation task for a specific instance."""

    @task(task_id=f"create_schema_{instance_key}")
    def create_schema_task():
        """Create test data schema (users and transactions tables)."""
        hook = MsSqlHook(mssql_conn_id=instance_config["conn_id"])
        conn = hook.get_conn()
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
        hook = MsSqlHook(mssql_conn_id=instance_config["conn_id"])
        conn = hook.get_conn()
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
        hook = MsSqlHook(mssql_conn_id=instance_config["conn_id"])
        conn = hook.get_conn()
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
        hook = MsSqlHook(mssql_conn_id=instance_config["conn_id"])
        conn = hook.get_conn()
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
    description="Load synthetic test data into SQL Server instances (RDS and Azure SQL)",
    start_date=datetime(2026, 2, 1),
    schedule_interval=None,  # Manual trigger only
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
            create_db = MsSqlOperator(
                task_id=f"create_database_{instance_key}",
                mssql_conn_id=instance_config["conn_id"],
                sql=CREATE_DATABASE_SQL,
                autocommit=True,
            )
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
