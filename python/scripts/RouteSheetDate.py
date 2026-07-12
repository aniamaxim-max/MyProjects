import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config.config import OUTPUT_FILE
from utils.db import query_to_df
from utils.email_sender import send_email


def export_and_send():
    query = "SELECT TOP 10 * FROM CarNumbers"

    print("Подключение к базе данных...")
    try:
        df = query_to_df(query)
        print(f"Запрос успешно выполнен. Получено строк: {len(df)}")

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
    <p>Во вложении находится свежая выгрузка по запросу <b>pbi.v_routesheet</b>.</p>
    <p>Содержимое выгрузки:</p>
    {table_html}
    </body></html>
    """

    try:
        send_email(
            to="aniamaxim@gmail.com",
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
