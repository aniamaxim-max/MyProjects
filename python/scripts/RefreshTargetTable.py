import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from utils.db import execute_command


def refresh():
    command = "EXEC work.pbi.RefreshTargetTable '20260101', 'F'"

    print("Подключение к базе данных...")
    try:
        execute_command(command)
        print("Процедура успешно выполнена.")
    except Exception as e:
        print(f"Ошибка при выполнении процедуры: {e}")


if __name__ == "__main__":
    refresh()
