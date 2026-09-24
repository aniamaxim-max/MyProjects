#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Фильтрация строк в большом .xlsx по числовому значению в одном столбце.

Строки-шапки (первые N) сохраняются всегда, остальные строки остаются, только
если значение в указанном столбце >= порога. Результат пишется в новый файл.

Файл не читается целиком через openpyxl (для 350+ МБ Excel это часы работы и
гигабайты памяти), а переписывается потоково на уровне XML внутри zip-контейнера.
За счёт этого:
  * сохраняются стили, заливки, ширины столбцов, форматы чисел, sharedStrings;
  * память остаётся константной (в обработке одна строка за раз).

Формулы (теги <f>) при выгрузке заменяются своими кэшированными значениями
(<v>): после удаления строк номера строк меняются, и формулы стали бы
некорректными. calcChain.xml при этом удаляется.

Прохода по листу два: первый — подсчёт строк, чтобы записать корректный
<dimension>, второй — запись отфильтрованного листа.

Использование:
    python filter_xlsx_rows.py "Custom/Prepare/IM_06_2026.xlsx"
    python filter_xlsx_rows.py "in.xlsx" -o "out.xlsx" --column AI --min 5000
"""

import argparse
import os
import posixpath
import re
import shutil
import sys
import zipfile

ROW_END = b"</row>"
TAG_ROW = re.compile(rb"<row\b")
TAG_FORMULA_SELF = re.compile(rb"<f\b[^>]*/>")
TAG_FORMULA_PAIR = re.compile(rb"<f\b[^>]*>.*?</f>", re.S)
ATTR_ROW_R = re.compile(rb'(<row r=")\d+(")')
ATTR_CELL_R = re.compile(rb'(<c r="[A-Z]+)\d+(")')
TAG_DIMENSION = re.compile(rb"<dimension ref=\"[^\"]*\"/>")
DIMENSION_COL = re.compile(rb"<dimension ref=\"[^\"]*:([A-Z]+)\d+\"")
DEFNAME_ROW = re.compile(rb"(\$[A-Z]{1,3}\$)\d+(</definedName>)")
AUTOFILTER_ROW = re.compile(rb'(<autoFilter\b[^>]*\bref="[A-Z]+\d+:[A-Z]+)\d+(")')
OVERRIDE_CALCCHAIN = re.compile(rb"<Override PartName=\"/xl/calcChain\.xml\"[^>]*/>")
RELS_CALCCHAIN = re.compile(rb"<Relationship [^>]*calcChain\.xml\"[^>]*/>")
TAG_CALCPR = re.compile(rb"<calcPr\b[^>]*/>")


def configure_stdout():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def col_letter_to_index(letter):
    idx = 0
    for ch in letter.upper():
        if not ("A" <= ch <= "Z"):
            raise SystemExit("Некорректная буква столбца: %r" % letter)
        idx = idx * 26 + (ord(ch) - ord("A") + 1)
    if idx == 0:
        raise SystemExit("Пустая буква столбца")
    return idx


def _attrs(xml_fragment):
    return dict(re.findall(r'([A-Za-z_:][\w:.-]*)="([^"]*)"', xml_fragment))


def resolve_sheet_path(zf, sheet_name):
    """Возвращает путь к XML-файлу листа внутри архива."""
    workbook = zf.read("xl/workbook.xml").decode("utf-8")
    rels = zf.read("xl/_rels/workbook.xml.rels").decode("utf-8")

    sheets = [(_attrs(t).get("name", ""), _attrs(t).get("r:id", ""))
              for t in re.findall(r"<sheet\b[^>]*/?>", workbook)]
    if not sheets:
        raise SystemExit("В workbook.xml не найдено ни одного листа")

    if sheet_name is None:
        _, rid = sheets[0]
    else:
        found = [s for s in sheets if s[0] == sheet_name]
        if not found:
            raise SystemExit("Лист %r не найден. Доступные: %s" % (sheet_name, [s[0] for s in sheets]))
        _, rid = found[0]

    targets = {}
    for tag in re.findall(r"<Relationship\b[^>]*/?>", rels):
        attrs = _attrs(tag)
        if "Id" in attrs:
            targets[attrs["Id"]] = attrs.get("Target", "")
    if rid not in targets:
        raise SystemExit("Не найден Target для %s" % rid)

    path = targets[rid].lstrip("/")
    return posixpath.normpath(path if path.startswith("xl/") else posixpath.join("xl", path))


def stream_parts(zf, sheet_path):
    """Генератор ("prologue"|"row"|"suffix", xml_bytes) по XML листа."""
    with zf.open(sheet_path) as src:
        prologue_yielded = False
        buf = b""
        while True:
            chunk = src.read(1 << 22)
            if not chunk:
                break
            buf += chunk
            parts = buf.split(ROW_END)
            buf = parts.pop()
            for part in parts:
                if not prologue_yielded:
                    pos = TAG_ROW.search(part)
                    if pos:
                        yield "prologue", part[:pos.start()]
                        yield "row", part[pos.start():] + ROW_END
                    else:
                        yield "prologue", part
                    prologue_yielded = True
                else:
                    yield "row", part + ROW_END
        if not prologue_yielded:
            raise SystemExit("В листе не найдено ни одной строки (тег <row>)")
        yield "suffix", buf


def get_cell_xml(row, col):
    match = re.search(rb'<c r="' + col + rb'\d+"[^>]*?/>', row)
    if match:
        return match.group(0)
    match = re.search(rb'<c r="' + col + rb'\d+"[^>]*?>.*?</c>', row, re.S)
    return match.group(0) if match else None


def cell_number(row, col):
    """Возвращает (число, None) либо (None, причина)."""
    cell = get_cell_xml(row, col)
    if cell is None:
        return None, "нет ячейки %s" % col.decode()
    if b't="s"' in cell or b't="str"' in cell or b't="inlineStr"' in cell:
        return None, "в ячейке %s не число" % col.decode()
    if cell.endswith(b"/>") or b"<v>" not in cell:
        return None, "пусто"
    raw = re.search(rb"<v>([^<]*)</v>", cell).group(1).strip().replace(b",", b".")
    try:
        return float(raw), None
    except ValueError:
        return None, "не число: %r" % raw[:40]


def rewrite_row(row_xml, new_no):
    """Убирает формулы и перенумеровывает строку с её ячейками."""
    row_xml = TAG_FORMULA_SELF.sub(b"", row_xml)
    row_xml = TAG_FORMULA_PAIR.sub(b"", row_xml)
    row_xml = ATTR_ROW_R.sub(lambda m: m.group(1) + str(new_no).encode() + m.group(2), row_xml, count=1)
    return ATTR_CELL_R.sub(lambda m: m.group(1) + str(new_no).encode() + m.group(2), row_xml)


def count_pass(zf, sheet_path, col, threshold, header_rows, verbose):
    """Первый проход: сколько строк останется, какая последняя колонка."""
    kept = dropped = anomalies = seen = 0
    last_col = b"Z"
    for kind, data in stream_parts(zf, sheet_path):
        if kind == "prologue":
            dim = DIMENSION_COL.search(data)
            if dim:
                last_col = dim.group(1)
            continue
        if kind == "suffix":
            continue
        seen += 1
        drop = False
        if seen > header_rows:
            value, reason = cell_number(data, col)
            if value is None or value < threshold:
                drop = True
                dropped += 1
                if value is None and reason != "пусто":
                    anomalies += 1
                    if verbose and anomalies <= 20:
                        print("  строка %d отброшена: %s" % (seen, reason))
        if not drop:
            kept += 1
        if verbose and seen % 100000 == 0:
            print("  подсчёт: %d строк, останется %d" % (seen, kept), flush=True)
    return kept, dropped, anomalies, last_col


def write_pass(zf, sheet_path, dst, col, threshold, header_rows, total_kept, last_col, verbose):
    """Второй проход: запись отфильтрованного XML листа."""
    seen = written = 0
    dimension = b'<dimension ref="A1:%s%d"/>' % (last_col, total_kept)
    for kind, data in stream_parts(zf, sheet_path):
        if kind == "prologue":
            dst.write(TAG_DIMENSION.sub(dimension, data, count=1) if TAG_DIMENSION.search(data)
                      else data.replace(b"<sheetData>", dimension + b"<sheetData>", 1))
            continue
        if kind == "suffix":
            dst.write(AUTOFILTER_ROW.sub(
                lambda m: m.group(1) + str(total_kept).encode() + m.group(2), data))
            continue
        seen += 1
        if verbose and seen % 100000 == 0:
            print("  запись: %d из %d строк" % (seen, written), flush=True)
        if seen > header_rows:
            value, _ = cell_number(data, col)
            if value is None or value < threshold:
                continue
        dst.write(rewrite_row(data, written + 1))
        written += 1
    if written != total_kept:
        raise SystemExit("Расхождение проходов: подсчитано %d, записано %d" % (total_kept, written))


def patch_workbook(data, kept):
    data = DEFNAME_ROW.sub(lambda m: m.group(1) + str(kept).encode() + m.group(2), data)

    def add_fullcalc(match):
        tag = match.group(0)
        return tag if b"fullCalcOnLoad" in tag else tag[:-2] + b' fullCalcOnLoad="1"/>'

    if TAG_CALCPR.search(data):
        return TAG_CALCPR.sub(add_fullcalc, data, count=1)
    return data.replace(b"</workbook>", b'<calcPr fullCalcOnLoad="1"/></workbook>', 1)


def main():
    configure_stdout()
    parser = argparse.ArgumentParser(description="Фильтрация строк .xlsx по числовому значению в столбце")
    parser.add_argument("input", help="исходный .xlsx")
    parser.add_argument("-o", "--output", help="новый .xlsx (по умолчанию <input>_filtered.xlsx)")
    parser.add_argument("--sheet", help="имя листа (по умолчанию первый)")
    parser.add_argument("--column", default="AI", help="буква столбца (по умолчанию AI)")
    parser.add_argument("--min", dest="threshold", type=float, default=5000,
                        help="минимальное значение для сохранения строки (по умолчанию 5000)")
    parser.add_argument("--header-rows", type=int, default=1,
                        help="сколько первых строк сохранить как шапку (по умолчанию 1)")
    parser.add_argument("--quiet", action="store_true", help="без вывода прогресса")
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        raise SystemExit("Файл не найден: %s" % args.input)
    col = args.column.upper()
    col_letter_to_index(col)

    out_path = args.output
    if not out_path:
        base, ext = os.path.splitext(args.input)
        out_path = base + "_filtered" + (ext or ".xlsx")
    if os.path.abspath(args.input) == os.path.abspath(out_path):
        raise SystemExit("Исходный и выходной файл совпадают")
    tmp_path = out_path + ".part"
    for path in (out_path, tmp_path):
        if os.path.exists(path):
            os.remove(path)

    verbose = not args.quiet
    print("Файл: %s" % args.input)
    print("Условие: столбец %s >= %s, шапка: %d строк" % (col, args.threshold, args.header_rows))

    with zipfile.ZipFile(args.input, "r") as zin:
        sheet_path = resolve_sheet_path(zin, args.sheet)
        names = zin.namelist()
        print("Лист: %s" % sheet_path)

        kept, dropped, anomalies, last_col = count_pass(
            zin, sheet_path, col.encode(), args.threshold, args.header_rows, verbose)
        if kept <= args.header_rows:
            print("Внимание: под условие не попала ни одна строка данных")

        with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as zout:
            zout.writestr("[Content_Types].xml", OVERRIDE_CALCCHAIN.sub(b"", zin.read("[Content_Types].xml")))
            if "_rels/.rels" in names:
                zout.writestr("_rels/.rels", zin.read("_rels/.rels"))

            with zout.open(sheet_path, "w") as dst:
                write_pass(zin, sheet_path, dst, col.encode(), args.threshold,
                           args.header_rows, kept, last_col, verbose)

            for name in names:
                if name in ("[Content_Types].xml", "_rels/.rels", sheet_path, "xl/calcChain.xml"):
                    continue
                if name == "xl/_rels/workbook.xml.rels":
                    zout.writestr(name, RELS_CALCCHAIN.sub(b"", zin.read(name)))
                elif name == "xl/workbook.xml":
                    zout.writestr(name, patch_workbook(zin.read(name), kept))
                else:
                    with zin.open(name) as src, zout.open(name, "w") as dst:
                        shutil.copyfileobj(src, dst, 1 << 22)

    os.replace(tmp_path, out_path)
    print("Оставлено строк (с шапкой): %d, удалено: %d" % (kept, dropped))
    if anomalies:
        print("  внимание: удалено строк с нечисловым/отсутствующим значением: %d" % anomalies)
    print("Готово: %s (%.1f МБ)" % (out_path, os.path.getsize(out_path) / 1048576))


if __name__ == "__main__":
    main()
