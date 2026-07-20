import os
import sys
import sqlite3

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config.config import OUTPUT_FILE
from utils.db import query_to_df
from utils.email_sender import send_email


def export_and_send():
    query = "EXEC pbi.GetRouteSheetIssues"

    print("Подключение к базе данных...")
    try:
        df = query_to_df(query)
        print(f"Запрос успешно выполнен. Получено строк: {len(df)}")

        db_path = os.path.join(os.path.dirname(__file__), "..", "data", "exceptions.db")
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        with sqlite3.connect(db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS route_sheet_exceptions (
                    RouteSheetRefHex TEXT NOT NULL,
                    Reason TEXT NOT NULL,
                    PRIMARY KEY (RouteSheetRefHex, Reason)
                )
            """)
            exceptions = set(
                (r[0], r[1])
                for r in conn.execute(
                    "SELECT RouteSheetRefHex, Reason FROM route_sheet_exceptions"
                )
            )

        before = len(df)
        mask = df.apply(
            lambda r: (r["RouteSheetRefHex"], r["Причина"]) in exceptions, axis=1
        )
        df = df[~mask].drop(columns=["RouteSheetRefHex"])
        print(f"Исключено строк: {before - len(df)}")

        df.to_excel(OUTPUT_FILE, index=False, engine="openpyxl")
        print(f"Данные сохранены в файл: {OUTPUT_FILE}")
    except Exception as e:
        print(f"Ошибка при работе с БД: {e}")
        return

    table_html = df.to_html(index=False, border=0, classes="data-table")

    html_body = f"""
    <html><head>
    <style>
        .data-table {{ border-collapse: collapse; font-family: Arial, sans-serif; font-size: 13px; }}
        .data-table th {{ background-color: #4472C4; color: white; padding: 8px 12px; text-align: left; }}
        .data-table td {{ padding: 6px 12px; border-bottom: 1px solid #ddd; }}
        .data-table tr:nth-child(even) {{ background-color: #f2f2f2; }}
    </style>
    </head><body>
    <h3>Приветствую!</h3>
    <p>Во вложении находится свежая выгрузка по запросу <b>pbi.GetRouteSheetIssues</b>.</p>
    <p>Содержимое выгрузки:</p>
    {table_html}
    </body></html>
    """

    try:
        send_email(
            to="hanna.maksymova@stellar.ua, votd@stellar-ua.com",
            subject="Автоматическая выгрузка: Маршрутные листы",
            body=html_body,
            attachments=[OUTPUT_FILE],
        )
        print("Письмо успешно отправлено!")
    except Exception as e:
        print(f"Ошибка при отправке почты: {e}")

    finally:
        if os.path.exists(OUTPUT_FILE):
            os.remove(OUTPUT_FILE)
            print("Временный файл удален.")


if __name__ == "__main__":
    export_and_send()
