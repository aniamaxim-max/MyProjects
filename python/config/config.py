import os

DB_CONFIG = {
    "server": os.environ.get("MS_SQL_DB_SERVER", ""),
    "database": os.environ.get("MS_SQL_DB_DATABASE", ""),
    "user": os.environ.get("MS_SQL_DB_USER", ""),
    "password": os.environ.get("MS_SQL_DB_PASSWORD", ""),
}

MAIL_CONFIG = {
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587,
    "sender_email": os.environ.get("GMAIL_ADDRESS", ""),
    "sender_password": os.environ.get("GMAIL_PASSWORD", ""),
}

FMS_CONFIG = {
    "api_key": os.environ.get("API_KEY_TRIMEX", ""),
    "base_url": "https://api.fm-track.com",
}

FMS_API_KEYS = [
    {"name": "TRIMEX", "key": os.environ.get("API_KEY_TRIMEX", "")},
    {"name": "STELLAR", "key": os.environ.get("API_KEY_STELLAR", "")},
]

OUTPUT_FILE = "routesheet_report.xlsx"

SQLITE_DB_PATH = "data/coordinates.db"
LOG_FILE = "logs/fetch_coords.log"
