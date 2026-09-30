#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Экспорт таблицы declarations из customs.db в файл для Power BI.

Power BI не имеет встроенного коннектора SQLite, а Python-источник капризен
(pandas 3.x + враппер). Поэтому выгружаем данные в Parquet/CSV и грузим штатным
коннектором «Файл».

Использование:
    python export_customs.py                       # customs_export.parquet (все строки)
    python export_customs.py --no-duplicates       # без строк, где Дубль = 1
    python export_customs.py --format csv          # customs_export.csv
    python export_customs.py --sql "SELECT ... " --out my.parquet
"""

import argparse
import os
import sqlite3
import sys

import pandas as pd

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DB = os.path.join(BASE_DIR, "customs.db")


def main():
    ap = argparse.ArgumentParser(description="Экспорт declarations из customs.db для Power BI")
    ap.add_argument("--db", default=DEFAULT_DB, help="путь к customs.db")
    ap.add_argument("--table", default="declarations", help="имя таблицы")
    ap.add_argument("--sql", default=None, help="произвольный SELECT (перебивает --table)")
    ap.add_argument("--out", default=None, help="путь к выходному файлу")
    ap.add_argument("--format", choices=["parquet", "csv"], default="parquet")
    ap.add_argument("--no-duplicates", action="store_true", help="исключить строки с Дубль = 1")
    args = ap.parse_args()

    sql = args.sql or ('SELECT * FROM "%s"' % args.table)
    if args.no_duplicates and not args.sql:
        sql += ' WHERE "Дубль" = 0'

    out = args.out or os.path.join(BASE_DIR, "customs_export." + args.format)

    conn = sqlite3.connect(args.db)
    try:
        df = pd.read_sql_query(sql, conn)
    finally:
        conn.close()

    if args.format == "parquet":
        df.to_parquet(out, index=False)
    else:
        df.to_csv(out, index=False, encoding="utf-8-sig")

    size_mb = os.path.getsize(out) / 1024 / 1024
    print("Экспорт готов: %s" % out)
    print("  строк: %d | колонок: %d | размер: %.1f МБ" % (len(df), len(df.columns), size_mb))


if __name__ == "__main__":
    sys.exit(main())
