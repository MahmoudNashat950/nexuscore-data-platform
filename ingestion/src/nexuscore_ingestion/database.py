from psycopg_pool import ConnectionPool

from nexuscore_ingestion.config import settings


pool = ConnectionPool(
    conninfo=settings.database_url,
    min_size=2,
    max_size=10,
    open=False,
)


def open_pool() -> None:
    pool.open()


def close_pool() -> None:
    pool.close()

def check_database() -> bool:
    try:
        with pool.connection() as conn:
            conn.execute("SELECT 1")
        return True
    except Exception:
        return False