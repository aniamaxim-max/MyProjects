import argparse
import datetime
import os
import shutil
import sys

import win32com.client


REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
CUSTOM_DIR = os.path.join(REPO_ROOT, "Custom")


def default_files():
    return sorted(
        os.path.join(CUSTOM_DIR, f)
        for f in os.listdir(CUSTOM_DIR)
        if f.lower().endswith((".xlsb", ".xlsx")) and not f.lower().endswith(".bak")
    )

EXCEL_SERIAL_EPOCH = datetime.date(1899, 12, 30)


def to_serial_day(value):
    """Normalize a date cell (Excel serial or string) to a comparable day key."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    text = str(value).strip()
    if not text:
        return None
    for fmt in ("%d.%m.%Y", "%Y-%m-%d", "%d/%m/%Y", "%d.%m.%Y %H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            dt = datetime.datetime.strptime(text, fmt)
            return (dt.date() - EXCEL_SERIAL_EPOCH).days
        except ValueError:
            continue
    return None


def to_amount(value):
    """Normalize a numeric cell (weight / invoice value) to a canonical string."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return f"{value:.3f}"
    text = str(value).strip()
    if not text:
        return None
    text = text.replace(" ", "").replace("\u00a0", "").replace(",", ".")
    try:
        return f"{float(text):.3f}"
    except ValueError:
        return None


def norm_text(value):
    if value is None:
        return ""
    return str(value).strip()


def norm_key(value):
    text = norm_text(value)
    return text.replace(" ", "").replace("\u00a0", "")


def find_header_row(data, ncols):
    """First row that contains a 'Дата ВМД' header."""
    for r in range(min(5, len(data))):
        row = data[r]
        for c in range(min(ncols, len(row))):
            if "дата вмд" in norm_text(row[c]).lower():
                return r
    return 0


def find_columns(header_row_values):
    """Map headers to column indexes (0-based); returns preferred + fallback columns."""
    date_col = None
    weight_col = None      # Вага брутто
    weight_fb = None       # fallback: Вага нетто
    invoice_col = None     # Фактурна вартість, грн
    invoice_fb = None      # fallback: Фактурна вартість, $/иная
    comb_col = None
    year_col = None
    num_col = None
    for c, raw in enumerate(header_row_values):
        text = norm_text(raw)
        low = text.lower()
        if date_col is None and "дата вмд" in low:
            date_col = c
        elif weight_col is None and ("брутто" in low or "бруто" in low) and "нетто" not in low:
            weight_col = c
        elif weight_fb is None and "нетто" in low and "брутто" not in low:
            weight_fb = c
        elif invoice_col is None and ("фактурна" in low or "фактурная" in low) and "грн" in low:
            invoice_col = c
        elif invoice_fb is None and ("фактурна" in low or "фактурная" in low):
            invoice_fb = c
        elif comb_col is None and ("комбінований" in low or "комбинированный" in low):
            comb_col = c
        elif year_col is None and low.rstrip(" ,").startswith(("рік", "год", "рок")):
            year_col = c
        elif num_col is None and low.strip() in ("номер декларації", "номер декларации"):
            num_col = c
    return date_col, weight_col, weight_fb, invoice_col, invoice_fb, comb_col, year_col, num_col


def build_vmd(row, comb_col, year_col, num_col):
    get = lambda idx: norm_key(row[idx]) if idx is not None and idx < len(row) else ""
    comb = get(comb_col)
    if comb_col is not None and year_col is not None and num_col is not None:
        return f"{comb}/{get(year_col)}/{get(num_col)}" if comb else ""
    if comb_col is not None:
        return comb
    if year_col is not None and num_col is not None:
        year = get(year_col)
        return f"{year}/{get(num_col)}" if year else ""
    return ""


def make_key(row, date_col, wcol, icol, comb_col, year_col, num_col):
    day = to_serial_day(row[date_col]) if date_col is not None else None
    weight = to_amount(row[wcol]) if wcol is not None and wcol < len(row) else None
    invoice = to_amount(row[icol]) if icol is not None and icol < len(row) else None
    vmd = build_vmd(row, comb_col, year_col, num_col)
    if not vmd or day is None or weight is None or invoice is None:
        return None
    return day, vmd, weight, invoice


def process_sheet(ws):
    used = ws.UsedRange
    if used is None or used.Count == 0:
        return 0
    data = used.Value2
    nrows = used.Rows.Count
    ncols = used.Columns.Count

    if not isinstance(data, tuple):
        data = ((data,),)
    data = [row if isinstance(row, tuple) else (row,) for row in data]
    ncols = max(ncols, max(len(row) for row in data))

    header_row = find_header_row(data, ncols)
    if header_row >= nrows:
        return 0
    headers = list(data[header_row]) + [""] * (ncols - len(data[header_row]))

    date_col, weight_col, weight_fb, invoice_col, invoice_fb, comb_col, year_col, num_col = find_columns(headers)
    wcol = weight_col if weight_col is not None else weight_fb
    icol = invoice_col if invoice_col is not None else invoice_fb

    missing = []
    if date_col is None:
        missing.append("Дата ВМД")
    if wcol is None:
        missing.append("Вага брутто/нетто")
    if icol is None:
        missing.append("Фактурна вартість")
    if comb_col is None and (year_col is None or num_col is None):
        missing.append("Номер декларації")
    if missing:
        print(f"  Лист '{ws.Name}': не найдены колонки {', '.join(missing)} — пропуск")
        return 0

    substitutions = []
    if weight_col is None:
        substitutions.append("вага нетто вместо брутто")
    if invoice_col is None:
        substitutions.append("фактурна без грн")

    dup_col = None
    for c, raw in enumerate(headers):
        if norm_text(raw).lower() == "дубль":
            dup_col = c
            break

    if dup_col is None:
        dup_col = ncols
        ws.Cells.Item(header_row + 1, dup_col + 1).Value = "Дубль"

    counts = {}
    order = []
    for r in range(header_row + 1, nrows):
        row = list(data[r]) + [""] * (ncols - len(data[r]))
        key = make_key(row, date_col, wcol, icol, comb_col, year_col, num_col)
        if key is None:
            continue
        if key in counts:
            counts[key] += 1
        else:
            counts[key] = 1
            order.append(key)

    is_dup = {}
    seen = set()
    for r in range(header_row + 1, nrows):
        row = list(data[r]) + [""] * (ncols - len(data[r]))
        key = make_key(row, date_col, wcol, icol, comb_col, year_col, num_col)
        if key is None:
            is_dup[r] = False
            continue
        if key in seen:
            is_dup[r] = True
        else:
            seen.add(key)
            is_dup[r] = False

    values = [[bool(is_dup.get(r, False))] for r in range(header_row + 1, nrows)]
    if values:
        first = header_row + 2
        last = header_row + 1 + len(values)
        ws.Range(
            ws.Cells.Item(first, dup_col + 1),
            ws.Cells.Item(last, dup_col + 1),
        ).Value2 = values

    n_groups = sum(1 for k in order if counts[k] >= 2)
    n_flagged = sum(1 for k in order if counts[k] >= 2 for _ in range(counts[k] - 1))
    note = f"; {', '.join(substitutions)}" if substitutions else ""
    print(f"  Лист '{ws.Name}': строк данных={nrows - header_row - 1}, "
          f"групп-дублей={n_groups}, помечено TRUE={n_flagged}{note}")
    return n_flagged


def process_file(path):
    if not os.path.isfile(path):
        print(f"Файл не найден: {path}")
        return
    bak = path + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
        print(f"Резервная копия: {bak}")

    app = win32com.client.DispatchEx("Excel.Application")
    app.Visible = False
    app.DisplayAlerts = False
    app.EnableEvents = False
    total = 0
    try:
        wb = app.Workbooks.Open(path, UpdateLinks=0)
        prev_calc = None
        try:
            try:
                prev_calc = app.Calculation
                app.Calculation = -4135  # xlCalculationManual
            except Exception:
                pass
            for ws in wb.Worksheets:
                total += process_sheet(ws)
        finally:
            if prev_calc is not None:
                try:
                    app.Calculation = prev_calc
                except Exception:
                    pass
            wb.Save()
            wb.Close(True)
    finally:
        app.Quit()
    print(f"Готово: {path} (помечено TRUE: {total})")


def main():
    parser = argparse.ArgumentParser(
        description="Пометить дубли ВМД колонкой «Дубль» (TRUE/FALSE). "
                    "Без аргументов — все файлы в папке Custom."
    )
    parser.add_argument("files", nargs="*", help="Пути к .xlsb/.xlsx-файлам (по умолчанию все файлы в Custom/)")
    args = parser.parse_args()
    files = args.files or default_files()
    for f in files:
        process_file(f)


if __name__ == "__main__":
    sys.exit(main())
