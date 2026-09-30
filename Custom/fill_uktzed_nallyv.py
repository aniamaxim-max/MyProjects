#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Дозаповнення стовпців «Код УКТЗЕД_4» (C) і «Налив» (AU) у .xlsx.

C (Код УКТЗЕД_4): очищається і заповнюється за формулою
    =IF(LEN(AA)=9; LEFT(AA;3); LEFT(AA;4)), де AA — «Код УКТЗЕД».

AU (Налив): TRUE/FALSE ставиться ЛИШЕ там, де спрацювало одне з правил:
    1) брутто > нетто                                  -> FALSE
    2) код(4 знаки) < 1500                             -> FALSE
    3) код(4 знаки) > 3914                             -> FALSE
    4) опис містить «налив»                            -> TRUE
    5) опис містить «насип»/«навал»/«гранул»           -> FALSE
    6) код починається з 15,17,18,20,22,2707,2710,2711,2712,2713,2804,2806,
       2807,2808,2809,2811,2814,2815,2827,2828,2833,2835,2839,2847,29,31,34,
       3906,3907,3909,3911                             -> TRUE
    7) код починається з 25,26,3825                    -> FALSE
Правила застосовуються по порядку, перше відповідне визначає результат.
Якщо жодне не спрацювало — Налив залишається порожнім.

Коди (4 знаки) усіх рядків без правила збираються в окремий .xlsx.

Використання:
    python fill_uktzed_nallyv.py "file1.xlsx" ["file2.xlsx" ...] [-o list.xlsx]
"""

import argparse
import os
import re
import shutil
import sys
import zipfile
from collections import Counter, defaultdict

import openpyxl

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from filter_xlsx_rows import col_letter_to_index, resolve_sheet_path  # noqa: E402

ROW_END = b"</row>"
ROW_TAG = re.compile(rb"<row\b[^>]*>")
ROW_R = re.compile(rb'<row r="(\d+)"')
CELL = re.compile(rb'<c r="([A-Z]+)\d+"([^>]*?)(?:/>|>(.*?)</c>)', re.S)
CELL_S = re.compile(rb'\bs="(\d+)"')
CELL_V = re.compile(rb"<v>([^<]*)</v>")
SI_TAG = re.compile(rb"<si\b")

TRUE_PREFIXES = ("15", "17", "18", "20", "22", "2707", "2710", "2711", "2712", "2713",
                 "2804", "2806", "2807", "2808", "2809", "2811", "2814", "2815", "2827",
                 "2828", "2833", "2835", "2839", "2847", "29", "31", "34",
                 "3906", "3907", "3909", "3911")
FALSE_PREFIXES = ("25", "26", "3825")

KEYWORDS = {"naliv": "налив", "nasyp": "насип", "naval": "навал", "granul": "гранул"}


def configure_stdout():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def scan_shared_strings(zf, shared_path):
    hits = {k: set() for k in KEYWORDS}
    if shared_path not in zf.namelist():
        return hits
    idx = 0
    buf = b""
    with zf.open(shared_path) as f:
        while True:
            chunk = f.read(1 << 22)
            if not chunk:
                break
            buf += chunk
            parts = buf.split(b"</si>")
            buf = parts.pop()
            for frag in parts:
                if not SI_TAG.search(frag):
                    continue
                text = b"".join(re.findall(rb"<t\b[^>]*>(.*?)</t>", frag, re.S)).decode("utf-8", "replace").lower()
                for key, word in KEYWORDS.items():
                    if word in text:
                        hits[key].add(idx)
                idx += 1
    return hits


def aa_to_str(raw):
    raw = raw.strip()
    if re.fullmatch(rb"-?\d+", raw):
        return raw.decode()
    try:
        f = float(raw)
        return str(int(f)) if f.is_integer() else raw.decode()
    except ValueError:
        return raw.decode()


def code4_of(aa_str):
    if not aa_str:
        return None, None
    raw = aa_str[:3] if len(aa_str) == 9 else aa_str[:4]
    return raw.zfill(4), raw


def compute_naliv(brutto, netto, code4, flags):
    """(True|False|None, причина). None — жодне правило не спрацювало."""
    if brutto is not None and netto is not None and brutto > netto:
        return False, "брутто>нетто"
    if code4:
        try:
            n = int(code4)
        except ValueError:
            n = None
        if n is not None:
            if n < 1500:
                return False, "код<1500"
            if n > 3914:
                return False, "код>3914"
    if flags.get("naliv"):
        return True, "опис:налив"
    if flags.get("nasyp") or flags.get("naval") or flags.get("granul"):
        return False, "опис:насип/навал/гранул"
    if code4 and code4.startswith(TRUE_PREFIXES):
        return True, "код:true"
    if code4 and code4.startswith(FALSE_PREFIXES):
        return False, "код:false"
    return None, "без правила"


def transform_row(frag, hits):
    m = ROW_R.search(frag)
    if not m or m.group(1) == b"1":
        return frag, None
    r = m.group(1).decode()

    row_tag = ROW_TAG.match(frag)
    if not row_tag:
        return frag, None
    body = frag[row_tag.end():]

    cells = [(col_letter_to_index(mo.group(1).decode()), mo.group(0), mo) for mo in CELL.finditer(body)]
    if b"".join(c[1] for c in cells) != body.strip():
        raise SystemExit("Не удалось разобрать строку %s без потерь" % r)
    by_col = {c[0]: c for c in cells}

    aa = by_col.get(27)
    ab = by_col.get(28)
    c_cell = by_col.get(3)

    aa_str = None
    if aa:
        v = CELL_V.search(aa[2].group(3) or b"")
        if v:
            aa_str = aa_to_str(v.group(1))
    code4, code_raw = code4_of(aa_str)

    def num(cell):
        if not cell:
            return None
        v = CELL_V.search(cell[2].group(3) or b"")
        if not v or v.group(1) == b"":
            return None
        try:
            return float(v.group(1).replace(b",", b"."))
        except ValueError:
            return None

    flags = {k: False for k in KEYWORDS}
    if ab:
        ab_attrs = ab[2].group(2)
        ab_inner = ab[2].group(3) or b""
        if b't="s"' in ab_attrs:
            v = CELL_V.search(ab_inner)
            if v and v.group(1):
                idx = int(v.group(1))
                for key in KEYWORDS:
                    if idx in hits[key]:
                        flags[key] = True
        else:
            text = b"".join(re.findall(rb"<t\b[^>]*>(.*?)</t>", ab_inner, re.S)).decode("utf-8", "replace").lower()
            for key, word in KEYWORDS.items():
                if word in text:
                    flags[key] = True

    naliv, reason = compute_naliv(num(by_col.get(35)), num(by_col.get(36)), code4, flags)

    c_style = CELL_S.search(c_cell[2].group(2)) if c_cell else None
    c_attrs = b' s="' + c_style.group(1) + b'"' if c_style else b""
    if code_raw:
        c_xml = b'<c r="C%s"%s t="inlineStr"><is><t>%s</t></is></c>' % (r.encode(), c_attrs, code_raw.encode())
    else:
        c_xml = b'<c r="C%s"%s/>' % (r.encode(), c_attrs)

    new_cells = [(col, xml) for col, xml, _ in cells if col not in (3, 47)]
    new_cells.append((3, c_xml))
    if naliv is not None:
        au_style = None
        for col in (46, 45, 43, 36, 35, 3):
            if col in by_col:
                au_style = CELL_S.search(by_col[col][2].group(2))
                if au_style:
                    break
        au_attrs = b' s="' + au_style.group(1) + b'"' if au_style else b""
        new_cells.append((47, b'<c r="AU%s"%s t="b"><v>%d</v></c>' % (r.encode(), au_attrs, 1 if naliv else 0)))
    new_cells.sort(key=lambda x: x[0])

    info = {"matched": naliv is not None, "naliv": naliv, "reason": reason,
            "code4": code4, "code_raw": code_raw, "aa": aa_str}
    return row_tag.group(0) + b"".join(xml for _, xml in new_cells), info


def process(path):
    print("Файл: %s" % os.path.basename(path))
    tmp_path = path + ".tmp"
    reasons = Counter()
    unrec = Counter()
    sample = {}
    matched = empty = true_cnt = false_cnt = 0

    with zipfile.ZipFile(path, "r") as zin:
        sheet_path = resolve_sheet_path(zin, None)
        hits = scan_shared_strings(zin, "xl/sharedStrings.xml")
        with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as zout:
            for name in zin.namelist():
                if name == sheet_path:
                    with zin.open(name) as src, zout.open(name, "w") as dst:
                        buf = b""
                        while True:
                            chunk = src.read(1 << 22)
                            if not chunk:
                                break
                            buf += chunk
                            parts = buf.split(ROW_END)
                            buf = parts.pop()
                            for frag in parts:
                                out, info = transform_row(frag, hits)
                                if info:
                                    reasons[info["reason"]] += 1
                                    if info["matched"]:
                                        matched += 1
                                        true_cnt += 1 if info["naliv"] else 0
                                        false_cnt += 0 if info["naliv"] else 1
                                    else:
                                        empty += 1
                                        unrec[(info["code4"] or "", info["code_raw"] or "")] += 1
                                        if info["code4"] and info["code4"] not in sample:
                                            sample[info["code4"]] = info["aa"]
                                dst.write(out + ROW_END)
                        dst.write(buf)
                else:
                    with zin.open(name) as src, zout.open(name, "w") as dst:
                        shutil.copyfileobj(src, dst, 1 << 22)

    os.replace(tmp_path, path)
    print("  Налив: TRUE=%d FALSE=%d; порожніх (без правила)=%d" % (true_cnt, false_cnt, empty))
    print("  причини:", dict(reasons))
    return {"unrec": unrec, "sample": sample}


def main():
    configure_stdout()
    parser = argparse.ArgumentParser(description="Заповнення Код УКТЗЕД_4 та Налив")
    parser.add_argument("inputs", nargs="+", help="відфільтровані .xlsx")
    parser.add_argument("-o", "--output", default="unrecognized_uktzed4.xlsx",
                        help="окремий файл з нерозпізнаними кодами")
    args = parser.parse_args()

    totals = Counter()
    per_file = {}
    samples = {}
    for path in args.inputs:
        if not os.path.isfile(path):
            raise SystemExit("Файл не найден: %s" % path)
        res = process(path)
        fname = os.path.basename(path)
        per_file[fname] = res["unrec"]
        for key, n in res["unrec"].items():
            totals[key] += n
        for c4, aa in res["sample"].items():
            samples.setdefault(c4, aa)

    print("\nРазом нерозпізнаних рядків: %d, унікальних кодів: %d" % (sum(totals.values()), len(totals)))

    out = args.output
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Разом"
    ws.append(["Код УКТЗЕД_4 (4 знаки)", "Код у файлі", "Кількість рядків", "Файли", "Приклад Код УКТЗЕД (AA)"])
    for (c4, raw), n in sorted(totals.items(), key=lambda kv: (-kv[1], kv[0][0])):
        files = ", ".join("%s: %d" % (f, c[(c4, raw)]) for f, c in per_file.items() if c.get((c4, raw)))
        ws.append([c4, raw, n, files, samples.get(c4)])
    for col, w in (("A", 22), ("B", 14), ("C", 16), ("D", 42), ("E", 26)):
        ws.column_dimensions[col].width = w

    ws2 = wb.create_sheet("Детально")
    ws2.append(["Файл", "Код УКТЗЕД_4 (4 знаки)", "Код у файлі", "Кількість рядків"])
    for fname, cnt in per_file.items():
        for (c4, raw), n in sorted(cnt.items(), key=lambda kv: (-kv[1], kv[0][0])):
            ws2.append([fname, c4, raw, n])
    for col, w in (("A", 30), ("B", 22), ("C", 14), ("D", 16)):
        ws2.column_dimensions[col].width = w
    wb.save(out)
    print("Перелік нерозпізнаних кодів: %s" % os.path.abspath(out))


if __name__ == "__main__":
    main()
