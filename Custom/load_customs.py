#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Загрузка Excel-файлов таможенных деклараций в единую SQLite-таблицу.

Каноническая схема и правила маппинга описаны в columns_mapping.json.

Использование:
    python load_customs.py --init                 # полная перезагрузка всех *.xlsx из папки
    python load_customs.py --analyze              # сухой прогон по всем файлам
    python load_customs.py --analyze "новый.xlsx" # сухой прогон по конкретному файлу
    python load_customs.py --file "новый.xlsx"    # перезагрузка одного файла
"""

import argparse
import json
import os
import re
import sqlite3
import sys
from datetime import datetime, date, timedelta

import openpyxl

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "columns_mapping.json")

EXCEL_EPOCH = datetime(1899, 12, 30)
DATE_FORMATS = ["%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%d.%m.%Y", "%d.%m.%y", "%d/%m/%Y"]

SQL_TYPES = {"TEXT": "TEXT", "DATE": "TEXT", "INTEGER": "INTEGER", "REAL": "REAL", "FLAG": "INTEGER"}


def configure_stdout():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def load_config():
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------- конвертеры

def norm_text(v):
    if v is None:
        return None
    if isinstance(v, bool):
        return "True" if v else "False"
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    if isinstance(v, int):
        return str(v)
    s = str(v).strip()
    return s if s != "" else None


def norm_digits(v, width):
    s = norm_text(v)
    if s is None:
        return None
    s = s.replace(" ", "")
    if re.fullmatch(r"\d+", s):
        return s.zfill(width)
    return s


def to_int(v):
    if v is None:
        return None
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, int):
        return v
    if isinstance(v, float):
        return int(round(v))
    s = str(v).strip().replace(" ", "").replace(",", ".")
    if s == "":
        return None
    try:
        return int(round(float(s)))
    except ValueError:
        return None


def to_real(v, decimals=4):
    if v is None:
        return None
    if isinstance(v, bool):
        return float(int(v))
    if isinstance(v, (int, float)):
        return round(float(v), decimals)
    s = str(v).strip().replace(" ", "").replace(",", ".")
    if s == "":
        return None
    try:
        return round(float(s), decimals)
    except ValueError:
        return None


def to_flag(v):
    if v is None:
        return 0
    if isinstance(v, bool):
        return 1 if v else 0
    if isinstance(v, (int, float)):
        return 1 if v else 0
    s = str(v).strip().lower()
    return 1 if s in ("true", "1", "так", "yes", "+") else 0


def to_date(v):
    if v is None:
        return None
    d = None
    if isinstance(v, bool):
        return None
    elif isinstance(v, datetime):
        d = v.date()
    elif isinstance(v, date):
        d = v
    elif isinstance(v, (int, float)):
        try:
            d = (EXCEL_EPOCH + timedelta(days=float(v))).date()
        except Exception:
            return None
    else:
        s = str(v).strip()
        for fmt in DATE_FORMATS:
            try:
                d = datetime.strptime(s, fmt).date()
                break
            except ValueError:
                continue
    if d is None:
        return None
    if d.year >= 4001:
        d = d.replace(year=d.year - 2000)
    return d.isoformat()


def extract_after_second_slash(v):
    if v is None:
        return None
    parts = str(v).split("/")
    if len(parts) >= 3:
        s = parts[2].strip()
        return s if s != "" else None
    return None


def dup_date_day(v):
    if v is None or isinstance(v, bool):
        return None
    if isinstance(v, datetime):
        return (v.date() - EXCEL_EPOCH.date()).days
    if isinstance(v, date):
        return (v - EXCEL_EPOCH.date()).days
    if isinstance(v, (int, float)):
        return int(v)
    s = str(v).strip()
    for fmt in DATE_FORMATS:
        try:
            return (datetime.strptime(s, fmt).date() - EXCEL_EPOCH.date()).days
        except ValueError:
            continue
    return None


def dup_amount(v):
    if v is None or isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return "%.3f" % float(v)
    s = str(v).strip().replace(" ", "").replace("\u00a0", "").replace(",", ".")
    if s == "":
        return None
    try:
        return "%.3f" % float(s)
    except ValueError:
        return None


def dup_text(v):
    if v is None:
        return ""
    return str(v).strip().replace(" ", "").replace("\u00a0", "")


def find_dup_columns(header):
    """Колонки для расчёта дублей (по алгоритму mark_duplicates.py)."""
    cols = {"date": None, "weight": None, "weight_fb": None,
            "invoice": None, "invoice_fb": None, "comb": None, "year": None, "num": None}
    for c, raw in enumerate(header):
        if raw is None:
            continue
        low = str(raw).strip().lower()
        if cols["date"] is None and "дата вмд" in low:
            cols["date"] = c
        elif cols["weight"] is None and ("брутто" in low or "бруто" in low) and "нетто" not in low:
            cols["weight"] = c
        elif cols["weight_fb"] is None and "нетто" in low and "брутто" not in low:
            cols["weight_fb"] = c
        elif cols["invoice"] is None and "фактурн" in low and "грн" in low:
            cols["invoice"] = c
        elif cols["invoice_fb"] is None and "фактурн" in low:
            cols["invoice_fb"] = c
        elif cols["comb"] is None and ("комбінований" in low or "комбинированный" in low):
            cols["comb"] = c
        elif cols["year"] is None and low.rstrip(" ,").startswith(("рік", "год", "рок")):
            cols["year"] = c
        elif cols["num"] is None and low.strip() in ("номер декларації", "номер декларации"):
            cols["num"] = c
    return cols


def compute_dup_key(row, cols):
    def val(i):
        return row[i] if (i is not None and i < len(row)) else None

    day = dup_date_day(val(cols["date"]))
    wcol = cols["weight"] if cols["weight"] is not None else cols["weight_fb"]
    icol = cols["invoice"] if cols["invoice"] is not None else cols["invoice_fb"]
    weight = dup_amount(val(wcol))
    invoice = dup_amount(val(icol))
    comb = dup_text(val(cols["comb"]))
    year = dup_text(val(cols["year"]))
    num = dup_text(val(cols["num"]))
    if comb and year and num:
        vmd = "%s/%s/%s" % (comb, year, num)
    elif comb:
        vmd = comb
    elif year and num:
        vmd = "%s/%s" % (year, num)
    else:
        vmd = ""
    if not vmd or day is None or weight is None or invoice is None:
        return None
    return (day, vmd, weight, invoice)


def convert(value, spec, canon):
    kind = spec.get("kind")
    if kind == "after_second_slash":
        return extract_after_second_slash(value)
    cdef = canon[spec["target"]]
    t = cdef["type"]
    if t == "TEXT":
        if "pad_left" in cdef:
            return norm_digits(value, cdef["pad_left"])
        return norm_text(value)
    if t == "DATE":
        return to_date(value)
    if t == "INTEGER":
        return to_int(value)
    if t == "REAL":
        return to_real(value, cdef.get("decimals", 4))
    if t == "FLAG":
        return to_flag(value)
    return norm_text(value)


# ---------------------------------------------------------------- план колонок

def build_plan(header, cfg):
    """Возвращает (plan, unmapped). plan — список {target, src, kind?}."""
    canon = {c["name"]: c for c in cfg["canonical_columns"]}
    rename = cfg["rename"]
    drop = set(cfg["drop"])
    vmd = cfg["special_rules"]["vmd_number"]
    dt2 = cfg["special_rules"]["delivery_terms_2"]
    ccs = cfg["special_rules"]["currency_code_split"]

    direct_present = vmd["direct_source"] in header or any(
        rename.get(h) == vmd["target"] for h in header if h is not None)
    fb_idx = header.index(vmd["fallback_source"]) if vmd["fallback_source"] in header else None
    use_fallback = (not direct_present) and fb_idx is not None

    dt_idx = header.index(dt2["source"]) if dt2["source"] in header else None
    n_currency = sum(1 for h in header if h == ccs["source_name"])

    plan = []
    unmapped = []
    for idx, name in enumerate(header):
        if name is None:
            continue
        if use_fallback and idx == fb_idx:
            plan.append({"target": vmd["target"], "src": idx, "kind": "after_second_slash"})
            continue
        if dt_idx is not None and idx == dt_idx:
            has_place = dt2["place_column"] in header
            target = dt2["target_if_place_present"] if has_place else dt2["target_if_place_absent"]
            plan.append({"target": target, "src": idx})
            continue
        if n_currency >= 2 and name == ccs["source_name"]:
            plan.append({"src": idx, "kind": "currency_auto",
                         "code_target": ccs["code_target"],
                         "name_target": ccs["name_target"],
                         "code_regex": ccs["code_regex"]})
            continue
        target = rename.get(name, name)
        if target in canon:
            plan.append({"target": target, "src": idx})
        elif name in drop:
            continue
        else:
            unmapped.append(name)
    return plan, unmapped


def is_empty(v):
    return v is None or (isinstance(v, str) and v.strip() == "")


def iter_clean_rows(path, cfg, canon):
    """Генератор (values_tuple, unmapped) по строкам файла, без фантомов."""
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        ws = wb[wb.sheetnames[0]]
        it = ws.iter_rows(values_only=True)
        header = list(next(it))
        plan, unmapped = build_plan(header, cfg)

        key_idxs = {}
        for spec in plan:
            t = spec.get("target")
            if t in ("Опис товару", "Код УКТЗЕД") and t not in key_idxs:
                key_idxs[t] = spec["src"]
        i_desc = key_idxs.get("Опис товару")
        i_code = key_idxs.get("Код УКТЗЕД")

        dup_cfg = cfg["special_rules"].get("duplicate_flag")
        compute_dup = bool(dup_cfg) and dup_cfg["source_column"] not in header
        dup_cols = find_dup_columns(header) if compute_dup else None
        seen = set()

        for row in it:
            desc = row[i_desc] if (i_desc is not None and i_desc < len(row)) else None
            code = row[i_code] if (i_code is not None and i_code < len(row)) else None
            if is_empty(desc) and is_empty(code):
                continue
            values = {c["name"]: None for c in cfg["canonical_columns"]}
            for spec in plan:
                v = row[spec["src"]] if spec["src"] < len(row) else None
                if spec.get("kind") == "currency_auto":
                    s = norm_text(v)
                    if s is not None and re.fullmatch(spec["code_regex"], s):
                        values[spec["code_target"]] = to_int(v)
                    else:
                        values[spec["name_target"]] = norm_text(v)
                    continue
                values[spec["target"]] = convert(v, spec, canon)
            if compute_dup:
                key = compute_dup_key(row, dup_cols)
                if key is not None and key in seen:
                    values[dup_cfg["target"]] = 1
                else:
                    if key is not None:
                        seen.add(key)
                    values[dup_cfg["target"]] = 0
            yield values, unmapped
    finally:
        wb.close()


# ---------------------------------------------------------------- БД

def build_create_sql(cfg):
    coldefs = []
    for c in cfg["canonical_columns"]:
        coldefs.append('  "%s" %s' % (c["name"].replace('"', '""'), SQL_TYPES[c["type"]]))
    coldefs.append('  "%s" TEXT' % cfg["source_file_column"])
    return 'CREATE TABLE "%s" (\n%s\n);' % (cfg["table"], ",\n".join(coldefs))


def insert_columns(cfg):
    return [c["name"] for c in cfg["canonical_columns"]] + [cfg["source_file_column"]]


def build_insert_sql(cfg):
    cols = insert_columns(cfg)
    quoted = ", ".join('"%s"' % c.replace('"', '""') for c in cols)
    marks = ", ".join("?" * len(cols))
    return 'INSERT INTO "%s" (%s) VALUES (%s)' % (cfg["table"], quoted, marks)


def create_database(conn, cfg):
    conn.execute('DROP TABLE IF EXISTS "%s"' % cfg["table"])
    conn.execute(build_create_sql(cfg))
    conn.execute('CREATE INDEX "ix_%s_source_file" ON "%s" ("%s")' % (
        cfg["table"], cfg["table"], cfg["source_file_column"]))
    conn.commit()


def insert_file(conn, path, cfg, canon):
    fname = os.path.basename(path)
    cols = insert_columns(cfg)
    insert_sql = build_insert_sql(cfg)

    conn.execute('DELETE FROM "%s" WHERE "%s" = ?' % (cfg["table"], cfg["source_file_column"]), (fname,))

    kept = 0
    unmapped = []
    batch = []
    for values, munmapped in iter_clean_rows(path, cfg, canon):
        unmapped = munmapped
        batch.append(tuple(values[c] for c in cols[:-1]) + (fname,))
        if len(batch) >= 1000:
            conn.executemany(insert_sql, batch)
            kept += len(batch)
            batch.clear()
    if batch:
        conn.executemany(insert_sql, batch)
        kept += len(batch)
    conn.commit()
    return kept, unmapped


# ---------------------------------------------------------------- файлы

def list_xlsx(directory):
    return sorted(
        os.path.join(directory, f)
        for f in os.listdir(directory)
        if f.lower().endswith(".xlsx") and not f.startswith("~$")
    )


def resolve_files(names):
    if not names:
        return list_xlsx(BASE_DIR)
    out = []
    for n in names:
        p = n if os.path.isabs(n) else os.path.join(BASE_DIR, n)
        if not os.path.exists(p):
            print("  !! файл не найден: %s" % n)
            continue
        out.append(p)
    return out


def analyze_file(path, cfg):
    canon = {c["name"]: c for c in cfg["canonical_columns"]}
    fname = os.path.basename(path)
    print("=" * 90)
    print("ФАЙЛ: %s" % fname)

    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        ws = wb[wb.sheetnames[0]]
        it = ws.iter_rows(values_only=True)
        header = list(next(it))
        plan, unmapped = build_plan(header, cfg)

        present = {spec.get("target") for spec in plan}
        for spec in plan:
            if spec.get("kind") == "currency_auto":
                present.add(spec["code_target"])
                present.add(spec["name_target"])
        dup_cfg = cfg["special_rules"].get("duplicate_flag")
        compute_dup = bool(dup_cfg) and dup_cfg["source_column"] not in header
        if compute_dup:
            present.add(dup_cfg["target"])
        missing = [c["name"] for c in cfg["canonical_columns"] if c["name"] not in present]

        print("  колонок в файле: %d | смаплено: %d" % (len([h for h in header if h is not None]), len(plan)))
        if compute_dup:
            print("  Дубль: колонки нет -> будет рассчитана автоматически")
        if unmapped:
            print("  UNMAPPED (не распознаны, будут пропущены):")
            for u in unmapped:
                print("      - %r" % u)
        else:
            print("  UNMAPPED: нет")
        print("  незаполненных канонических колонок: %d" % len(missing))
        if missing:
            print("      " + ", ".join(missing))

        kept = 0
        empty = 0
        for row in it:
            key_desc = key_code = None
            for spec in plan:
                if spec.get("target") == "Опис товару":
                    key_desc = row[spec["src"]] if spec["src"] < len(row) else None
                elif spec.get("target") == "Код УКТЗЕД":
                    key_code = row[spec["src"]] if spec["src"] < len(row) else None
            if is_empty(key_desc) and is_empty(key_code):
                empty += 1
            else:
                kept += 1
        print("  строк всего: %d | к загрузке: %d | отброшено пустых: %d" % (kept + empty, kept, empty))
    finally:
        wb.close()
    return unmapped


def main():
    configure_stdout()
    parser = argparse.ArgumentParser(description="Загрузка деклараций в SQLite (Customs)")
    parser.add_argument("--init", action="store_true", help="полная перезагрузка всех файлов папки")
    parser.add_argument("--analyze", nargs="*", default=None, help="сухой прогон (без записи в БД)")
    parser.add_argument("--file", nargs="+", default=None, help="перезагрузка указанных файлов")
    args = parser.parse_args()

    cfg = load_config()
    canon = {c["name"]: c for c in cfg["canonical_columns"]}
    db_path = os.path.join(BASE_DIR, cfg["db_file"])

    if args.analyze is not None:
        files = resolve_files(args.analyze)
        all_unmapped = {}
        for p in files:
            for u in analyze_file(p, cfg):
                all_unmapped.setdefault(u, []).append(os.path.basename(p))
        print("=" * 90)
        if all_unmapped:
            print("ИТОГО UNMAPPED:")
            for u, fs in all_unmapped.items():
                print("  %r -> %s" % (u, ", ".join(fs)))
        else:
            print("ИТОГО: UNMAPPED нет")
        return

    if args.init:
        files = list_xlsx(BASE_DIR)
        conn = sqlite3.connect(db_path)
        create_database(conn, cfg)
        print("БД создана: %s" % db_path)
        total = 0
        for p in files:
            kept, unmapped = insert_file(conn, p, cfg, canon)
            total += kept
            note = ("  UNMAPPED: %s" % ", ".join(repr(u) for u in unmapped)) if unmapped else ""
            print("  + %-18s %7d строк%s" % (os.path.basename(p), kept, note))
        conn.close()
        print("ИТОГО загружено строк: %d" % total)
        return

    if args.file:
        files = resolve_files(args.file)
        if not os.path.exists(db_path):
            print("БД не найдена: %s (сначала запусти --init)" % db_path)
            return
        conn = sqlite3.connect(db_path)
        for p in files:
            kept, unmapped = insert_file(conn, p, cfg, canon)
            note = ("  UNMAPPED: %s" % ", ".join(repr(u) for u in unmapped)) if unmapped else ""
            print("  ~ %-18s %7d строк (reload)%s" % (os.path.basename(p), kept, note))
        conn.close()
        return

    parser.print_help()


if __name__ == "__main__":
    main()
