import os

DB_CONFIG = {
    "server": "vent\\sqlexpress",
    "database": "Ania",
    "user": "Ania",
    "password": os.environ.get("MS_SQL_DB_PASSWORD", ""),
}

MAIL_CONFIG = {
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587,
    "sender_email": os.environ.get("GMAIL_ADDRESS", ""),
    "sender_password": os.environ.get("GMAIL_PASSWORD", ""),
}

OUTPUT_FILE = "routesheet_report.xlsx"
