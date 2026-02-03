"""Test RDS SQL Server connection with a simple query."""

from __future__ import annotations

from datetime import datetime

from common.defaults import DEFAULT_ARGS

from airflow.decorators import dag, task
from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
from airflow.providers.microsoft.mssql.operators.mssql import MsSqlOperator


@dag(
    description="Test RDS SQL Server connection",
    start_date=datetime(2025, 2, 3),
    schedule_interval=None,  # Manual trigger only
    default_args=DEFAULT_ARGS,
    catchup=False,
)
def test_rds_sqlserver_dag():
    """DAG for testing RDS SQL Server connectivity."""

    # Test 0: Create application database if it doesn't exist
    create_database = MsSqlOperator(
        task_id="create_database",
        mssql_conn_id="rds_sqlserver",
        autocommit=True,  # Required for CREATE DATABASE (can't run in transaction)
        sql="""
            IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'synthetic_data')
            BEGIN
                CREATE DATABASE synthetic_data;
            END
        """,
    )

    # Test 1: Simple SELECT query to verify connection
    test_connection = MsSqlOperator(
        task_id="test_connection",
        mssql_conn_id="rds_sqlserver",
        sql="""
            USE synthetic_data;
            SELECT
                'Hello, World!' AS message,
                @@VERSION AS sql_server_version,
                DB_NAME() AS current_database;
        """,
    )

    # Test 2: Create a test table in our database
    create_test_table = MsSqlOperator(
        task_id="create_test_table",
        mssql_conn_id="rds_sqlserver",
        sql="""
            USE synthetic_data;

            IF OBJECT_ID('dbo.hello_world_test', 'U') IS NOT NULL
                DROP TABLE dbo.hello_world_test;

            CREATE TABLE dbo.hello_world_test (
                id INT IDENTITY(1,1) PRIMARY KEY,
                message NVARCHAR(100),
                created_at DATETIME DEFAULT GETDATE()
            );
        """,
    )

    # Test 3: Insert test data
    insert_test_data = MsSqlOperator(
        task_id="insert_test_data",
        mssql_conn_id="rds_sqlserver",
        sql="""
            USE synthetic_data;

            INSERT INTO dbo.hello_world_test (message)
            VALUES
                ('Hello from Airflow!'),
                ('RDS SQL Server is working!'),
                ('Test successful!');
        """,
    )

    # Test 4: Query the data using a Python task to show results
    @task
    def query_and_log_results():
        """Query test data and log results."""
        hook = MsSqlHook(mssql_conn_id="rds_sqlserver")
        conn = hook.get_conn()
        cursor = conn.cursor()

        # Switch to our database
        cursor.execute("USE synthetic_data")
        cursor.execute(
            "SELECT id, message, created_at FROM dbo.hello_world_test ORDER BY id"
        )
        results = cursor.fetchall()

        print("=" * 60)
        print("Test Results from RDS SQL Server:")
        print("=" * 60)
        for row in results:
            print(f"ID: {row[0]}, Message: {row[1]}, Created: {row[2]}")
        print("=" * 60)

        cursor.close()
        conn.close()

        return len(results)

    # Test 5: Cleanup - drop test table
    cleanup_test_table = MsSqlOperator(
        task_id="cleanup_test_table",
        mssql_conn_id="rds_sqlserver",
        sql="""
            USE synthetic_data;
            DROP TABLE IF EXISTS dbo.hello_world_test;
        """,
    )

    # Define task dependencies
    (
        create_database
        >> test_connection
        >> create_test_table
        >> insert_test_data
        >> query_and_log_results()
        >> cleanup_test_table
    )


run = test_rds_sqlserver_dag()
