import pyodbc
import pandas as pd


def build_conn_str(db_config: dict) -> str:
    return (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER=tcp:{db_config['server']};"
        f"DATABASE={db_config['database']};"
        f"UID={db_config['user']};"
        f"PWD={db_config['password']};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=yes;"
    )


def query_to_df(query: str, db_config: dict | None = None) -> pd.DataFrame:
    if db_config is None:
        from config.config import DB_CONFIG
        db_config = DB_CONFIG

    conn_str = build_conn_str(db_config)
    with pyodbc.connect(conn_str) as conn:
        return pd.read_sql(query, conn)
