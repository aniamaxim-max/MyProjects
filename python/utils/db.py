import time
import pyodbc
import pandas as pd

_TRANSIENT_SQLSTATES = {
    "08S01",  # Communication link failure
    "08001",  # Unable to connect
    "08003",  # Connection does not exist
    "08004",  # Server rejected the connection
    "HYT00",  # Timeout expired
}

_DEFAULT_CONNECT_TIMEOUT = 30
_DEFAULT_QUERY_TIMEOUT = 600
_MAX_ATTEMPTS = 3


def build_conn_str(db_config: dict) -> str:
    return (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER=tcp:{db_config['server']};"
        f"DATABASE={db_config['database']};"
        f"UID={db_config['user']};"
        f"PWD={db_config['password']};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=yes;"
        f"Connection Timeout={_DEFAULT_CONNECT_TIMEOUT};"
    )


def _is_transient(exc: pyodbc.Error) -> bool:
    sqlstate = exc.args[0] if exc.args else ""
    return sqlstate in _TRANSIENT_SQLSTATES


def query_to_df(
    query: str,
    db_config: dict | None = None,
    timeout: int = _DEFAULT_QUERY_TIMEOUT,
    attempts: int = _MAX_ATTEMPTS,
) -> pd.DataFrame:
    if db_config is None:
        from config.config import DB_CONFIG
        db_config = DB_CONFIG

    conn_str = build_conn_str(db_config)
    last_error = None
    for attempt in range(1, attempts + 1):
        conn = None
        try:
            conn = pyodbc.connect(conn_str, autocommit=True)
            conn.timeout = timeout
            return pd.read_sql(query, conn)
        except pyodbc.Error as exc:
            last_error = exc
            if attempt >= attempts or not _is_transient(exc):
                raise
            time.sleep(2 * attempt)
        finally:
            if conn is not None:
                conn.close()

    raise last_error


def execute_command(
    command: str,
    db_config: dict | None = None,
    timeout: int = _DEFAULT_QUERY_TIMEOUT,
    attempts: int = _MAX_ATTEMPTS,
) -> None:
    if db_config is None:
        from config.config import DB_CONFIG
        db_config = DB_CONFIG

    conn_str = build_conn_str(db_config)
    last_error = None
    for attempt in range(1, attempts + 1):
        conn = None
        try:
            conn = pyodbc.connect(conn_str, autocommit=True)
            conn.timeout = timeout
            cursor = conn.cursor()
            cursor.execute(command)
            cursor.close()
            return
        except pyodbc.Error as exc:
            last_error = exc
            if attempt >= attempts or not _is_transient(exc):
                raise
            time.sleep(2 * attempt)
        finally:
            if conn is not None:
                conn.close()

    raise last_error
