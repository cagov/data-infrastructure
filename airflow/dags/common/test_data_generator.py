"""Reusable test data generation functions for SQL Server instances.

This module provides functions for generating and loading synthetic test data
using the Faker library. These functions are used by both Airflow DAGs and
standalone scripts for local testing.
"""

from typing import List, Tuple, Dict, Any
from faker import Faker
import random


def create_schema(cursor):
    """Create test data schema (users and transactions tables).

    Drops existing tables if present and recreates them.

    Args:
        cursor: Database cursor
    """
    print("Creating test data schema...")

    # Drop in FK dependency order
    cursor.execute("DROP TABLE IF EXISTS dbo.transactions;")
    cursor.execute("DROP TABLE IF EXISTS dbo.users;")
    cursor.connection.commit()

    # Create users table
    cursor.execute("""
        CREATE TABLE dbo.users (
            id INT IDENTITY(1,1) PRIMARY KEY,
            email NVARCHAR(255) NOT NULL UNIQUE,
            first_name NVARCHAR(100) NOT NULL,
            last_name NVARCHAR(100) NOT NULL,
            phone_number NVARCHAR(50),
            date_of_birth DATE,
            created_at DATETIME2 DEFAULT GETDATE()
        );
    """)
    cursor.connection.commit()

    # Create transactions table
    cursor.execute("""
        CREATE TABLE dbo.transactions (
            id INT IDENTITY(1,1) PRIMARY KEY,
            user_id INT NOT NULL,
            amount DECIMAL(12, 2) NOT NULL,
            description NVARCHAR(500),
            transaction_type NVARCHAR(50) NOT NULL,
            status NVARCHAR(50) DEFAULT 'completed',
            transaction_date DATETIME2 DEFAULT GETDATE(),
            CONSTRAINT FK_transactions_user_id
                FOREIGN KEY (user_id) REFERENCES dbo.users(id)
                ON DELETE CASCADE
        );
    """)
    cursor.connection.commit()

    print("✓ Schema created")


def generate_users(num_users: int, seed: int = 42) -> List[Tuple]:
    """Generate synthetic user data using Faker.

    Args:
        num_users: Number of users to generate
        seed: Random seed for reproducibility

    Returns:
        List of tuples ready for bulk insert:
        (email, first_name, last_name, phone_number, date_of_birth)
    """
    fake = Faker()
    Faker.seed(seed)
    random.seed(seed)

    users: List[Tuple] = []
    for _ in range(num_users):
        users.append(
            (
                fake.unique.email(),
                fake.first_name(),
                fake.last_name(),
                fake.phone_number(),
                fake.date_of_birth(minimum_age=18, maximum_age=90),
            )
        )

    print(f"Generated {len(users)} users")
    return users


def generate_transactions(
    user_ids: List[int], transactions_per_user: int, seed: int = 42
) -> List[Tuple]:
    """Generate synthetic transaction data using Faker.

    Args:
        user_ids: List of user IDs to create transactions for
        transactions_per_user: Average number of transactions per user
        seed: Random seed for reproducibility

    Returns:
        List of tuples ready for bulk insert:
        (user_id, amount, description, transaction_type, status, transaction_date)
    """
    num_transactions = len(user_ids) * transactions_per_user

    fake = Faker()
    Faker.seed(seed)
    random.seed(seed)

    transaction_types = ["purchase", "refund", "transfer"]
    statuses = ["pending", "completed", "failed"]
    status_weights = [0.1, 0.8, 0.1]  # Mostly completed

    transactions: List[Tuple] = []

    for _ in range(num_transactions):
        transactions.append(
            (
                random.choice(user_ids),
                float(fake.pydecimal(left_digits=5, right_digits=2, positive=True)),
                fake.sentence(nb_words=6),
                random.choice(transaction_types),
                random.choices(statuses, weights=status_weights)[0],
                fake.date_time_between(start_date="-1y", end_date="now"),
            )
        )

    print(f"Generated {len(transactions)} transactions for {len(user_ids)} users")
    return transactions


def bulk_insert_users(cursor, users: List[Tuple], batch_size: int = 500) -> int:
    """Insert users in batches.

    Assumes users table already exists.

    Args:
        cursor: Database cursor
        users: List of user tuples from generate_users()
        batch_size: Number of records to insert per batch

    Returns:
        Total count of users inserted
    """
    print(f"Inserting {len(users)} users in batches of {batch_size}...")

    insert_sql = """
        INSERT INTO dbo.users
        (email, first_name, last_name, phone_number, date_of_birth)
        VALUES (?, ?, ?, ?, ?)
    """

    for i in range(0, len(users), batch_size):
        batch = users[i : i + batch_size]
        cursor.executemany(insert_sql, batch)
        cursor.connection.commit()
        print(f"  Inserted {min(i + batch_size, len(users))}/{len(users)} users")

    cursor.execute("SELECT COUNT(*) FROM dbo.users")
    count = cursor.fetchone()[0]
    print(f"✓ Total users in database: {count}")

    return count


def bulk_insert_transactions(
    cursor, transactions: List[Tuple], batch_size: int = 500
) -> int:
    """Insert transactions in batches.

    Assumes transactions table already exists.

    Args:
        cursor: Database cursor
        transactions: List of transaction tuples from generate_transactions()
        batch_size: Number of records to insert per batch

    Returns:
        Total count of transactions inserted
    """
    print(f"Inserting {len(transactions)} transactions in batches of {batch_size}...")

    insert_sql = """
        INSERT INTO dbo.transactions
        (user_id, amount, description, transaction_type, status, transaction_date)
        VALUES (?, ?, ?, ?, ?, ?)
    """

    for i in range(0, len(transactions), batch_size):
        batch = transactions[i : i + batch_size]
        cursor.executemany(insert_sql, batch)
        cursor.connection.commit()
        print(
            f"  Inserted {min(i + batch_size, len(transactions))}/{len(transactions)} transactions"
        )

    cursor.execute("SELECT COUNT(*) FROM dbo.transactions")
    count = cursor.fetchone()[0]
    print(f"✓ Total transactions in database: {count}")

    return count


def verify_data_integrity(cursor) -> Dict[str, Any]:
    """Verify data integrity and compute statistics.

    Args:
        cursor: Database cursor

    Returns:
        Dict with verification results including counts, stats, and status breakdown

    Raises:
        ValueError: If data integrity issues are found (e.g., orphaned transactions)
    """
    print("Running data integrity checks...")

    results = {}

    # Count users
    cursor.execute("SELECT COUNT(*) FROM dbo.users")
    results["user_count"] = cursor.fetchone()[0]

    # Count transactions
    cursor.execute("SELECT COUNT(*) FROM dbo.transactions")
    results["transaction_count"] = cursor.fetchone()[0]

    # Check for orphaned transactions (FK integrity)
    cursor.execute("""
        SELECT COUNT(*)
        FROM dbo.transactions t
        LEFT JOIN dbo.users u ON t.user_id = u.id
        WHERE u.id IS NULL
    """)
    orphaned = cursor.fetchone()[0]
    results["orphaned_transactions"] = orphaned

    if orphaned > 0:
        raise ValueError(
            f"Data integrity check FAILED: Found {orphaned} orphaned transactions!"
        )

    # Transaction statistics
    cursor.execute("""
        SELECT
            AVG(amount) as avg_amount,
            MIN(amount) as min_amount,
            MAX(amount) as max_amount,
            SUM(amount) as total_amount
        FROM dbo.transactions
    """)
    row = cursor.fetchone()
    results["transaction_stats"] = {
        "avg": float(row[0]) if row[0] else 0.0,
        "min": float(row[1]) if row[1] else 0.0,
        "max": float(row[2]) if row[2] else 0.0,
        "total": float(row[3]) if row[3] else 0.0,
    }

    # Status breakdown
    cursor.execute("""
        SELECT status, COUNT(*) as count
        FROM dbo.transactions
        GROUP BY status
        ORDER BY count DESC
    """)
    results["status_breakdown"] = {row[0]: row[1] for row in cursor.fetchall()}

    # Pretty print results
    print("=" * 60)
    print("Verification Results")
    print("=" * 60)
    print(f"Users: {results['user_count']}")
    print(f"Transactions: {results['transaction_count']}")
    print(f"Orphaned transactions: {results['orphaned_transactions']}")
    print(f"\nTransaction Statistics:")
    print(f"  Avg: ${results['transaction_stats']['avg']:.2f}")
    print(f"  Min: ${results['transaction_stats']['min']:.2f}")
    print(f"  Max: ${results['transaction_stats']['max']:.2f}")
    print(f"  Total: ${results['transaction_stats']['total']:.2f}")
    print(f"\nStatus Breakdown:")
    for status, count in results["status_breakdown"].items():
        print(f"  {status}: {count}")
    print("=" * 60)
    print("✓ Verification complete")

    return results
