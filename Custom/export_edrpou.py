#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Справочник ЄДРПОУ -> Найменування (уникальные украинские организации).

Берёт уникальные непустые значения колонки
«Експорт - Код за ЄДРПОУ відправника, Імпорт - Код за ЄДРПОУ одержувача»
и соответствующее «Експорт - Найменування відправника, Імпорт - Найменування одержувача».
Если у кода несколько написаний имени — берётся первое по порядку загрузки (rowid).

Создаёт вьюху v_edrpou в customs.db и выгружает всё в Parquet.

Использование:
    python export_edrpou.py                  # edrpou_export.parquet
    python export_edrpou.py --format csv     # edrpou_export.csv
    python export_edrpou.py --out my.parquet
"""

import argparse
import os
import sqlite3
import sys

import pandas as pd

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DB = os.path.join(BASE_DIR, "customs.db")
TABLE = "declarations"

CODE = "Експорт - Код за ЄДРПОУ відправника, Імпорт - Код за ЄДРПОУ одержувача"
NAME = "Експорт - Найменування відправника, Імпорт - Найменування одержувача"

CREATE_INDEX = 'CREATE INDEX IF NOT EXISTS "ix_%s_edrpou" ON "%s" ("%s")' % (
    TABLE, TABLE, CODE.replace('"', '""'))
CREATE_VIEW = (
    'CREATE VIEW "v_edrpou" AS '
    'SELECT d."%s" AS "ЄДРПОУ", d."%s" AS "Найменування" '
    'FROM "%s" d '
    'WHERE d."%s" IS NOT NULL AND TRIM(d."%s") <> \'\' '
    'AND d.rowid = (SELECT MIN(x.rowid) FROM "%s" x WHERE x."%s" = d."%s")'
    % (CODE.replace('"', '""'), NAME.replace('"', '""'), TABLE,
       CODE.replace('"', '""'), CODE.replace('"', '""'),
       TABLE, CODE.replace('"', '""'), CODE.replace('"', '""')))


def ensure_view(conn):
    conn.execute(CREATE_INDEX)
    conn.execute('DROP VIEW IF EXISTS "v_edrpou"')
    conn.execute(CREATE_VIEW)
    conn.commit()


def main():
    ap = argparse.ArgumentParser(description="Экспорт справочника ЄДРПОУ из customs.db")
    ap.add_argument("--db", default=DEFAULT_DB, help="путь к customs.db")
    ap.add_argument("--out", default=None, help="путь к выходному файлу")
    ap.add_argument("--format", choices=["parquet", "csv"], default="parquet")
    args = ap.parse_args()

    out = args.out or os.path.join(BASE_DIR, "edrpou_export." + args.format)

    conn = sqlite3.connect(args.db)
    try:
        ensure_view(conn)
        df = pd.read_sql_query('SELECT "ЄДРПОУ", "Найменування" FROM "v_edrpou" ORDER BY "ЄДРПОУ"', conn)
    finally:
        conn.close()

    if args.format == "parquet":
        df.to_parquet(out, index=False)
    else:
        df.to_csv(out, index=False, encoding="utf-8-sig")

    size_kb = os.path.getsize(out) / 1024
    print("Экспорт готов: %s" % out)
    print("  организаций: %d | размер: %.1f КБ" % (len(df), size_kb))


if __name__ == "__main__":
    sys.exit(main())
