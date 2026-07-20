---
name: 1c-database-reading
description: Use when reading data from 1C enterprise database via SQL Server (pyodbc), working with 1C table naming conventions (_Document, _Reference, _Fld fields), writing JOIN queries between 1C objects, handling binary IDs, date offsets, or status filtering in 1C SQL databases.
---

# 1C Database Reading via SQL Server

## Overview

1C зберігає дані в SQL Server з нестандартними іменами таблиць і полів. Всі таблиці та поля мають системні імена (`_Document650`, `_Fld17682`). Використовуй `metadata_1c.json` як словник для маппінгу на зрозумілі назви.

## Повний каталог таблиць

**Файл:** `metadata_tables.md` (в цій же директорії) — повний каталог всіх таблиць 1С з описами, кількістю рядків, прикладами. Використовуй для пошуку потрібних таблиць перед написанням SQL.

Містить: 234 Reference (довідники), 105 Document (документи), 17 VT (табличні частини Document650), 20 InfoRg (регістри відомостей), AccRg (регістри накопичення), 609 Enum (перерахування).

## Ключові особливості 1С SQL

| Особливість | Деталь |
|-------------|--------|
| **Дата зі зміщенням** | 1С зберігає дати +2000 років (`2026` → `4026 в БД`) |
| **ID як binary(16)** | `_IDRRef` — бінарний, передавати через `bytes.fromhex()` |
| **Посилання (RRef)** | Поля типу `_Fld17685RRef` — це FK на `_IDRRef` іншої таблиці |
| **_Posted** | `0x01` = проведений документ |
| **Рядки** | Поля типу `_Fld_S` — рядкові (не посилання) |
| **Полімофні посилання** | Поле може мати `_TYPE`, `_RTRef`, `_RRRef` суфікси. Приклад: `_Fld17681_TYPE`, `_Fld17681_RTRef`, `_Fld17681_RRRef`. JOIN тільки по `_RRRef` частині. |
| **Непослідовний `_RRRef`** | Деякі поля мають підкреслення: `_Fld17681_RRRef`, інші — ні: `_Fld17721RRef`. Це поведінка 1С — перевіряй кожне поле окремо через реальний SQL або metadata_1c.json. |

## Таблиці метаданих (metadata_1c.json)

### Document650 — Замовлення на використання ТС (`уатЗаказНаИспользование`)

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `OrderId` | Унікальний ID (binary) |
| `_Number` | `OrderNumber` | Номер замовлення |
| `_Date_Time` | `OrderDate` | Дата (з офсетом +2000) |
| `_Posted` | — | 0x01 = проведено |
| `_Fld17682` | `PeriodStart` | Початок періоду |
| `_Fld17683` | `PeriodEnd` | Кінець періоду |
| `_Fld28758` | `VehicleNumber` | Номер ТЗ |
| `_Fld28759` | `TrailerNumber` | Номер причепа |
| `_Fld17710_S` | `DriverName` | Водій (рядок) |
| `_Fld17710_RRRef` | — | Водій (FK → Reference254) |
| `_Fld17685RRef` | `StatusID` | Статус (FK, binary) |
| `_Fld17681_RRRef` | `CustomerID` | Замовник (FK → Reference123) |
| `_Fld17687RRef` | `OrderTypeID` | Тип замовлення |
| `_Fld17700RRef` | `RouteID` | Маршрут (FK → Reference283/304) |
| `_Fld17721RRef` | `DirectionID` | Напрямок (FK → Reference288) |
| `_Fld17697` | `Comment` | Коментар |
| `_Fld26805` | `LoadingAddress` | Адреса завантаження |
| `_Fld26806` | `UnloadingAddress` | Адреса розвантаження |
| `_Fld32935` | `LoadingAddressFull` | Повна адреса завантаження |
| `_Fld32938` | `UnloadingAddressFull` | Повна адреса розвантаження |
| `_Fld32937` | `LoadingEnterprise` | Підприємство завантаження |
| `_Fld32940` | `UnloadingEnterprise` | Підприємство розвантаження |
| `_Fld32936` | `LoadingCoordinates` | Координати завантаження |
| `_Fld32939` | `UnloadingCoordinates` | Координати розвантаження |
| `_Fld17709` | `CMR` | CMR номер |
| `_Fld34316` | `CMRNumber` | Номер CMR |
| `_Fld34310` | `CMRLoadingDate` | Дата завантаження CMR |
| `_Fld17692` | `DocumentSum` | Сума документу |
| `_Fld26927` | `ActualWeightTons` | Фактична вага (т) |
| `_Fld17742` | `TransportConditions` | Умови перевезення |
| `_Fld17743` | `SpecialNotes` | Особливі відмітки |
| `_Fld34309` | `MaxCargoWeight` | Макс. вага вантажу |
| `_Fld33896` | `GMP` | GMP ознака |
| `_Fld33985` | `FoodCargo` | Харчовий вантаж |
| `_Fld34308` | `VetControl` | Ветеринарний контроль |
| `_Fld17749` | `NormativeTimeLoading` | Нормативний час завантаження |
| `_Fld17750` | `NormativeTimeUnloading` | Нормативний час розвантаження |
| `_Fld17694` | `IsConfirmed` | 0x00 = статус "На узгодженні" (очікує підтвердження); 0x01 = підтверджено (90% записів) |
| `_Fld17708` | `IsSubcontractor` | Субпідрядне або нестандартне замовлення (7% fill = True) |
| `_Fld17727` | `CargoDensity` | Щільність вантажу (ntext, зазвичай порожнє). Для рідких вантажів: "gęstość 1,04" |
| `_Fld17736` | `IsInvoiced` | Виставлено рахунок/підписано акт (4.4% fill = True) |
| `_Fld17744` | `LoadingInstructions` | Інструкції завантаження (ntext). Правила поведінки на заводі, вимоги безпеки |
| `_Fld17745` | `CargoRestrictions` | Обмеження щодо попередніх вантажів (ntext). Список заборонених попередніх продуктів |
| `_Fld32715` | `cgr_LoadingEDRPOU` | ЄДРПОУ завантаження |
| `_Fld32716` | `cgr_UnloadingEDRPOU` | ЄДРПОУ розвантаження |
| `_Fld34323RRef` | `EKMT_ID` | ЄКМТ (FK → Reference116) |
| `_Fld33940RRef` | `WarehouseLoadingID` | Склад завантаження |
| `_Fld33941RRef` | `WarehouseUnloadingID` | Склад розвантаження |
| `_Fld34016RRef` | `BorderCrossingElectronicQueueID` | Електронна черга на кордоні |
| `_Fld17679RRef` | `CarrierOrgID` | Компанія-перевізник (FK → Reference162: "Стеллар МВ, ТОВ", "Трімекс", "Форланд") |
| `_Fld17686RRef` | `ResponsibleManagerID` | Відповідальний менеджер/логіст (FK → Reference177, ~60 осіб) |
| `_Fld17688RRef` | `ContractTypeID` | Тип договору (FK → Reference85, напр. "ДОГОВІР-ДОРУЧЕННЯ") |
| `_Fld17693RRef` | `CurrencyID` | Валюта замовлення (FK → Reference38, напр. "грн") |
| `_Fld17711RRef` | `CustomerTypeID` | Тип клієнта (FK → Reference173, напр. "Коммерческий") |
| `_Fld17713` | `ContractedRate` | Договірна ставка фрахту (numeric, 92% fill). Зазвичай = DocumentSum. Range: 10–651k |
| `_Fld17734` | `RateNote` | Коментар до ставки або формула розрахунку курсу (74% fill). Приклади: ім'я водія, "1035 (Краківець) є * 50,8830 (курс НБУ)" |
| `_Fld17751` | `FreeLoadingTime` | Безкоштовний час завантаження (52% fill). Приклади: "12 год", "24.03 - 09:00" |
| `_Fld17752` | `FreeUnloadingTime` | Безкоштовний час розвантаження (50% fill). Аналогічно _Fld17751 |
| `_Fld17753` | `EmptyRunRate` | Ставка за порожній пробіг (80% fill). Приклади: "12 грн/км", "узгоджується" |
| `_Fld17754` | `StandbyRate` | Штраф за простій (82% fill). Приклади: "1500 грн/доба" |
| `_Fld17755` | `PaymentTerms` | Умови оплати (81% fill). Приклади: "30 к/д від дати оформлення рахунка" |
| `_Fld17768` | `LoadedKm` | Навантажений пробіг (км), 81% fill. Range: ~85–1314 km |
| `_Fld17770` | `EmptyKm` | Порожній пробіг/подача (км), 85% fill. Range: 1–6582 km |
| `_Fld27138` | `AllowedWaitingTime` | Дозволений час очікування на завантаженні/розвантаженні (58% fill). Приклади: "9 год", "24 год" |
| `_Fld27200` | `DeliveryDateOnly` | Дата доставки без часу (95% fill, зміщення +2000). Дублює PeriodEnd (date-only) |
| `_Fld27366` | `ActualLoadingDate` | Фактична дата завантаження (15% fill, зміщення +2000). Близька до PeriodStart |
| `_Fld27424` | `RouteDeviationAllowance` | Допуск відхилення від маршруту — текст (56% fill). Приклади: "2 км доп", "7 км допуск" |
| `_Fld27425` | `DeviationNotes` | Коментар щодо фактичного відхилення маршруту (42% fill). Приклади: "немає відхилення" |
| `_Fld33870` | `ActualDepartureTime` | Фактичний час відправлення з бази (18% fill, зміщення +2000). Близько до PeriodStart |
| `_Fld33872` | `InvoiceDueDate` | Строк оплати або дія договору (24% fill, зміщення +2000). Може бути на рік пізніше OrderDate |

### Reference123 — Контрагенти (`Справочник.Контрагенты`)

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `CustomerId` | ID (binary) |
| `_Description` | `CustomerName` | Назва |
| `_Code` | `CustomerCode` | Код |
| `_Fld2160` | `EDRPOU` | ЄДРПОУ |
| `_Fld2143` | `FullName` | Повна назва |
| `_Fld2148` | `INN` | ІПН |
| `_Fld34260` | `NIP` | NIP (польський ід.) |
| `_Fld2166` | `NameEnglish` | Назва англійською |
| `_Fld2162` | `IsNonResident` | Нерезидент |

### Reference254 — Фізичні особи / Водії

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `DriverId` | ID (binary) |
| `_Description` | `DriverName` | ПІБ водія |

### Reference283 — Маршрути (`уатМаршруты`)

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `RouteId` | ID (binary) |
| `_Description` | `RouteName` | Назва |
| `_Code` | `RouteCode` | Код |
| `_Fld3643` | `RouteNumber` | Номер маршруту |
| `_Fld3644RRef` | `ArrivalPointID` | FK → Reference299 |
| `_Fld3645RRef` | `DeparturePointID` | FK → Reference299 |
| `_Fld3646RRef` | `CountryID` | FK → Reference332 |
| `_Fld3647` | `FullName` | Повна назва |
| `_Fld3648` | `Distance` | Відстань |
| `_Fld32411` | `bgs_AddressRepresentation` | Google Maps URL |

### Reference288 — Напрямки (`Напрямки`)

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `DirectionId` | ID (binary) |
| `_Description` | `DirectionName` | Назва напрямку |
| `_Fld3744RRef` | `SourceCountryID` | FK → Reference332 (країна відправлення) |
| `_Fld3745RRef` | `TargetCountryID` | FK → Reference332 (країна призначення) |

### Reference299 — Пункти призначення (`уатПунктыНазначения`)

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `DestinationPointId` | ID (binary) |
| `_Description` | `DestinationPointName` | Назва |
| `_Code` | `DestinationPointCode` | Код |
| `_Fld3795RRef` | `CountryID` | FK → Reference332 |
| `_Fld3796` | `FullName` | Повна назва |
| `_Fld3798` | `LoadingAddress` | Адреса |
| `_Fld3800` | `ContactInfo` | Контактна інформація |
| `_Fld32412` | `bgs_AddressRepresentation` | Представлення адреси |
| `_Fld32413` | `bgs_Coordinates` | Координати |

### Reference304 — Зведені маршрути (`уатСводныеМаршруты`)

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `SummaryRouteId` | ID (binary) |
| `_Description` | `SummaryRouteName` | Назва |
| `_Code` | `SummaryRouteCode` | Код |
| `_Fld3841` | `RouteNumber` | Номер |
| `_Fld3842RRef` | `ArrivalPointID` | FK → Reference299 |
| `_Fld3843RRef` | `DeparturePointID` | FK → Reference299 |
| `_Fld3844` | `Distance` | Відстань |
| `_Fld3845RRef` | `SourceCountryID` | FK → Reference332 |
| `_Fld3846RRef` | `TargetCountryID` | FK → Reference332 |

### Reference332 — Країни

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `CountryId` | ID (binary) |
| `_Description` | `CountryName` | Назва країни |
| `_Code` | `CountryCode` | Код (ISO) |

### _Document650_VT17775 — Табличний рядок маршрутів замовлення

| SQL поле | Опис |
|----------|------|
| `_Document650_IDRRef` | FK на документ (батько) |
| `_LineNo17776` | Номер рядка |
| `_Fld17777RRef` | FK → Reference283 (маршрут) |
| `_Fld17790` | Порожній пробіг (bool) |

## Статуси замовлення (_Enum26798)

Таблиця: `dbo._Enum26798` (поля: `_IDRRef`, `_EnumOrder`)

```python
# Повний маппінг статусів замовлення (Document650)
# EnumOrder  Hex ID                                  Назва               TMS Status    Count (2026-03)
# --------  ---------------------------------------- -----------------  -----------   -----------
# 0          a7b16d22d4c0b0154bb7b2294ce861e7         Підготовлено       Booked        1,414
# 1          87fbc6d408a8fedf4fd6945ed28e7741         На узгодженні      Booked        123
# 2          a0c10503ce54d6e848c4f4190a4e05bc         Завершено          Delivered     3,644
# 3          aa9eca06593b365a454d6bb50777c12e         В роботі           In-Transit    326
# 4          81da511ac8ac6f8b4f78a244ba2c7efe         На виконанні       In-Transit    185
# 5          a5921cfb743b96584a328f31df41fcab         Проведено          Delivered     70,647
# 6          b7cc74ce4579f3a7446ed6cc7227830a         Відмовлено         Cancelled     3,094
# 7-12       (не використовуються)                                                    0
# 13         8736618f044679e444a18134950c7930         (невідомий)        Delivered     1
# 14         bbca232227825e02496eaaa1756b4a17         (невідомий)        Delivered     1
# 15-20      (не використовуються)                                                    0

STATUS_PREPARED     = "a7b16d22d4c0b0154bb7b2294ce861e7"   # EnumOrder=0  Підготовлено
STATUS_NEW          = "87fbc6d408a8fedf4fd6945ed28e7741"   # EnumOrder=1  На узгодженні
STATUS_COMPLETED    = "a0c10503ce54d6e848c4f4190a4e05bc"   # EnumOrder=2  Завершено
STATUS_ACTIVE       = "aa9eca06593b365a454d6bb50777c12e"   # EnumOrder=3  В роботі
STATUS_IN_PROGRESS  = "81da511ac8ac6f8b4f78a244ba2c7efe"   # EnumOrder=4  На виконанні
STATUS_POSTED       = "a5921cfb743b96584a328f31df41fcab"   # EnumOrder=5  Проведено (найбільший: 70K+)
STATUS_CANCELLED    = "b7cc74ce4579f3a7446ed6cc7227830a"   # EnumOrder=6  Відмовлено клієнтом

# Ukraine country ID
UA_COUNTRY_ID = "8fb38f26694ed7da11e67fef9c022ce1"

# Дата: 1С зберігає зі зміщенням +2000 років
DATE_OFFSET_YEARS = 2000
```

## Підключення (pyodbc)

```python
import pyodbc
import os
from dotenv import load_dotenv

load_dotenv()

conn_str = (
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={os.environ['DB_SERVER']};"
    f"DATABASE={os.environ['DB_NAME']};"
    f"UID={os.environ['DB_USER']};"
    f"PWD={os.environ['DB_PASSWORD']};"
    f"Encrypt=yes;"
    f"TrustServerCertificate=yes;"
    f"Connection Timeout=30;"
    f"Pooling=no;"
)

conn = pyodbc.connect(conn_str)
cursor = conn.cursor()
```

## Патерни SQL запитів

### Базовий запит документу з довідниками

```sql
SELECT TOP 100
    d._IDRRef          AS OrderId,          -- binary(16), конвертуй у hex
    LTRIM(RTRIM(d._Number)) AS OrderNumber, -- номер очищений від пробілів
    d._Date_Time       AS OrderDate,        -- datetime зі зміщенням +2000
    d._Fld28758        AS VehicleNumber,
    d._Fld28759        AS TrailerNumber,
    d._Fld17710_S      AS DriverName,       -- рядкове поле водія
    d._Fld26805        AS LoadingAddress,
    d._Fld26806        AS UnloadingAddress,
    c._Description     AS CustomerName,
    c._Fld2160         AS CustomerEDRPOU,
    dr._Description    AS DriverNameRef,
    dir._Description   AS DirectionName,
    dir._Fld3744RRef   AS StartCountryID,   -- binary, для порівняння з UA_ID
    dir._Fld3745RRef   AS EndCountryID
FROM dbo._Document650 d
LEFT JOIN dbo._Reference123 c   ON d._Fld17681_RRRef = c._IDRRef
LEFT JOIN dbo._Reference254 dr  ON d._Fld17710_RRRef = dr._IDRRef
LEFT JOIN dbo._Reference288 dir ON d._Fld17721RRef = dir._IDRRef
LEFT JOIN dbo._Reference304 sr  ON d._Fld17700RRef = sr._IDRRef
WHERE d._Posted = 0x01
  AND d._Fld17685RRef <> ?      -- виключити статус "завершено"
ORDER BY d._Date_Time DESC
```

### Фільтр за датою (з урахуванням зміщення +2000)

```python
from datetime import datetime, timedelta

# Конвертуй поточну дату для фільтрації
days = 90
date_from = datetime.now().replace(year=datetime.now().year + 2000) - timedelta(days=days)

cursor.execute("SELECT ... WHERE d._Date_Time >= ?", (date_from,))
```

### Фільтр за статусами (whitelist)

```python
include_hexes = [
    "aa9eca06593b365a454d6bb50777c12e",  # В роботі
    "87fbc6d408a8fedf4fd6945ed28e7741",  # На узгодженні
    "81da511ac8ac6f8b4f78a244ba2c7efe",  # На виконанні
]
# Конвертуй hex → bytes для SQL параметрів
include_params = [bytes.fromhex(h) for h in include_hexes]
placeholders = ', '.join(['?'] * len(include_params))

query = f"... WHERE d._Fld17685RRef IN ({placeholders})"
cursor.execute(query, include_params + [date_from])
```

### Конвертація результатів (binary ID → hex, дата → реальний рік)

```python
from decimal import Decimal

def format_row(row, cursor_description):
    columns = [col[0] for col in cursor_description]
    record = dict(zip(columns, row))

    for key, value in record.items():
        if isinstance(value, bytes):
            record[key] = value.hex()                   # binary ID → hex string
        elif isinstance(value, datetime):
            # 1С зберігає рік +2000 — при читанні відніми 2000
            real = value.replace(year=value.year - 2000)
            record[key] = real.isoformat()
        elif isinstance(value, Decimal):
            record[key] = float(value)                  # Decimal → float

    return record
```

### Пошук замовлення за номером

```sql
SELECT ...
FROM dbo._Document650 d
WHERE LTRIM(RTRIM(d._Number)) = ?
ORDER BY d._Date_Time DESC
```

```python
cursor.execute(query, (order_number.strip(),))
```

### Табличний рядок (вкладена таблиця маршрутів)

```sql
SELECT
    vt._LineNo17776,
    p._Description    AS RouteName,
    p._Fld32411       AS GoogleMapsUrl,
    vt._Fld17790      AS IsEmptyRun
FROM dbo._Document650_VT17775 vt
JOIN dbo._Reference283 p ON vt._Fld17777RRef = p._IDRRef
WHERE vt._Document650_IDRRef = ?
ORDER BY vt._LineNo17776
```

```python
# ID документу передавати як bytes
order_id_bytes = bytes.fromhex(order_id_hex)
cursor.execute(query, (order_id_bytes,))
```

## Reference219 — Статті витрат (`Справочник.СтатьиЗатрат`)

Довідник категорій витрат, використовується у табличній частині НВ (VT17903).

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `CostItemId` | ID (binary) |
| `_Description` | `CostItemName` | Назва статті |

**Ключові статті витрат (ПВ = планові, ЗВ = загальні/фактичні):**

| Hex ID | Назва |
|--------|-------|
| `b084d0df8a77c7a111eb550c4dd14160` | Митні послуги (358K рядків — найпопулярніша) |
| `93e78fef853b0aa111eb6308e31b08a0` | (стаття 3 — 148K) |
| `af0ed5fe0b3d32a411eb619a8fd78480` | (стаття 4 — 87K) |
| `8de59e02fdc0f6a111eb5990ad832d70` | (стаття 5 — 84K) |
| `86f5b68ac35e4eb511e679caa0ebcc81` | (стаття 6 — 78K) |
| `9647ce26e65997aa11eb774c4effebb1` | AD Blue |
| `86f5b68ac35e4eb511e679caa0ebcc80` | AD-BLUE для вантажних ТЗ (ПВ) |
| `822bdcff2aeab83211e686fe4daa8ee6` | Автобан (ПВ) |
| `835aba8f5a3507c811e725a478be5601` | Автобан_бух (ЗВ) |
| `980d02b31cc3e40111e7686734e50550` | Автомийка (ЗВ) |
| `a47702b31cc3e40111e7478508652bc2` | Автомийка (ПВ) |
| `be19b7bf43048aab11eb6ab286155500` | GPS |

## _Document650_VT17903 — Нормативні витрати (НВ) замовлення

Табличний рядок замовлення з **нормативними витратами**. 2М+ рядків, ~65K замовлень мають НВ.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення (binary) |
| `_LineNo17904` | `LineNumber` | Номер рядка |
| `_Fld17905` | `CostDate` | Дата витрати (зміщення +2000) |
| `_Fld17906RRef` | `CostItemID` | FK → Reference219 (стаття витрат) |
| `_Fld17907` | `PlannedAmount` | Планова сума |
| `_Fld17908` | `ActualAmount` | Фактична сума |
| `_Fld17909` | `AmountFormatted` | Сума як рядок (з пробілами) |
| `_Fld17910RRef` | `CurrencyID` | FK → валюта |
| `_Fld17911` | `Description` | Опис |

**Визначення чи НВ внесені:**
```sql
-- Замовлення де є хоча б один рядок НВ з ActualAmount > 0
SELECT DISTINCT vt._Document650_IDRRef
FROM _Document650_VT17903 vt
WHERE vt._Fld17908 > 0

-- Порівняння план vs факт
SELECT
    vt._Document650_IDRRef AS OrderId,
    SUM(vt._Fld17907) AS TotalPlanned,
    SUM(vt._Fld17908) AS TotalActual,
    CASE WHEN SUM(vt._Fld17908) > 0 THEN 'present' ELSE 'missing' END AS NVStatus
FROM _Document650_VT17903 vt
GROUP BY vt._Document650_IDRRef
```

## _Document650_VT17859 — Витрати рейсу (паливо, послуги)

Табличний рядок з фактичними витратами по рейсу. 76K рядків. Кількість × Ціна = Сума.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення |
| `_LineNo17860` | `LineNumber` | Номер рядка |
| `_Fld17861RRef` | `ServiceTypeID` | FK → тип послуги |
| `_Fld17865` | `IsExpense` | binary(1) прапорець |
| `_Fld17866` | `Quantity` | Кількість (напр. літри палива) |
| `_Fld17867` | `UnitPrice` | Ціна за одиницю |
| `_Fld17868` | `TotalAmount` | Сума (Quantity × UnitPrice) |
| `_Fld17870` | `VATAmount` | Сума ПДВ |

**Приклад:** `1726 × 27.36 = 47,223.36` — паливо (літри × ціна за літр)

## _Document650_VT17841 — Послуги/Матеріали рейсу

Табличний рядок з послугами та матеріалами. 64K рядків.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення |
| `_LineNo17842` | `LineNumber` | Номер рядка |
| `_Fld17843RRef` | `ItemID` | FK → номенклатура |
| `_Fld17844RRef` | `ItemGroupID` | FK → група |
| `_Fld17845RRef` | `UnitID` | FK → одиниця виміру |
| `_Fld17846` | `Quantity` | Кількість |
| `_Fld17847` | `UnitPrice` | Ціна за одиницю |
| `_Fld17848` | `TotalAmount` | Сума |

### Порожній пробіг (подача) у VT17775

Замовлення може мати **кілька маршрутів** у VT17775. Маршрути з `_Fld17790 = 0x01` — це **подача** (порожній пробіг + мийка):

```sql
-- Знайти маршрути подачі для замовлення
SELECT
    vt._LineNo17776,
    r._Description AS RouteName,
    vt._Fld17790 AS IsEmptyRun  -- 0x01 = порожній пробіг/подача
FROM _Document650_VT17775 vt
JOIN _Reference283 r ON vt._Fld17777RRef = r._IDRRef
WHERE vt._Document650_IDRRef = ?
ORDER BY vt._LineNo17776
```

Приклади маршрутів подачі:
- "Дніпро - Дніпро (мийка Полупан)" — подача на мийку
- "Вінниця - Дніпро (UA) (мийка Полупан)" — подача + мийка
- "Краківець (UA) / Корчова (PL) - Tarnow (PL)" — подача до клієнта

**Важливо для розрахунку маржі:** `PeriodStart`/`PeriodEnd` документу включає весь час (подача + рейс). `pickup_date`/`delivery_date` у Load — тільки навантажений рейс. Для точного розрахунку маржі/день потрібно враховувати повний період.

### Додаткові дати Document650

| SQL поле | Опис |
|----------|------|
| `_Fld17682` | PeriodStart — початок повного періоду (включно з подачею) |
| `_Fld17683` | PeriodEnd — кінець повного періоду |
| `_Fld27366` | Фактична дата завантаження (якщо заповнена) |
| `_Fld33872` | Дата створення/реєстрації |
| `_Fld34309` | Максимальна вага вантажу (тонни) |
| `_Fld17692` | DocumentSum — сума в валюті контракту |
| `_Fld17691` | ExchangeRate — курс валюти до UAH |

### Валюта та курс в Document650

`DocumentSum` (`_Fld17692`) зберігається **у валюті контракту** (не завжди UAH).

| ExchangeRate | Валюта DocSum | Логіка конвертації в UAH |
|-------------|---------------|--------------------------|
| `1.0` | UAH | DocSum вже в UAH (50K+ замовлень) |
| `~50` | EUR | DocSum × ExchRate = UAH (Rate = НБУ EUR→UAH) |
| `~11-12` | PLN | DocSum × ExchRate = UAH (Rate = НБУ PLN→UAH) |
| `~41-43` | USD | DocSum × ExchRate = UAH (Rate = НБУ USD→UAH) |
| `~2600-3300` | EUR (×100) | Старий формат: Rate = EUR→UAH × 100 |

**Конвертація DocSum → EUR:**
```python
def doc_sum_to_eur(doc_sum, exch_rate, current_eur_rate):
    """Convert 1C DocumentSum to EUR using CurrencyRate from НБУ."""
    if exch_rate == 1.0:
        # DocSum in UAH → convert to EUR
        return doc_sum / current_eur_rate if current_eur_rate > 0 else 0
    elif exch_rate > 100:
        # Old format: rate per 100 units → DocSum already in foreign currency
        return doc_sum  # Already EUR (or close enough)
    else:
        # DocSum in foreign currency, exch_rate = UAH per unit
        # DocSum × exch_rate = UAH → / eur_rate = EUR
        uah_value = doc_sum * exch_rate
        return uah_value / current_eur_rate if current_eur_rate > 0 else 0
```

## _Document650_VT17818 — Етапи/Рейси замовлення

Табличний рядок з етапами перевезення. 80K рядків. Містить дати, адреси, ваги.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення |
| `_LineNo17819` | `LineNumber` | Номер рядка |
| `_Fld17820RRef` | `StageTypeID` | FK → тип етапу |
| `_Fld17821` | `Weight` | Вага |
| `_Fld17826` | `Distance` | Відстань (км) |
| `_Fld17833` | `StartDate` | Дата початку (зміщення +2000) |
| `_Fld17834` | `EndDate` | Дата завершення (зміщення +2000) |
| `_Fld17837` | `LoadingAddress` | Адреса завантаження |
| `_Fld17838` | `UnloadingAddress` | Адреса розвантаження |

## _Document650_VT17890 — Документи/файли замовлення

Табличний рядок з прикріпленими документами (CMR, ТТН, рахунки тощо). ~151K рядків.
**Це НЕ "точки маршруту" (як раніше вважалось) — це реєстр файлів замовлення.**

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення (Document650) |
| `_LineNo17891` | `LineNumber` | Номер рядка |
| `_Fld17893RRef` | `DocTypeID` | **Тип документа** (FK → `_Reference34298`: CMR / ТТН / Рахунок / Акт / …) |
| `_Fld17895` | `DocDate` | Дата документа (зміщення +2000) |
| `_Fld17896RRef` | `StorageID` | **FK → `_Reference259`** (запис у Хранилище Дополнительной Информации) |
| `_Fld17892` | `PointType` | Додаткова інфо (nvarchar) |
| `_Fld17897` | `Description` | Опис/примітка |

**Відомі ID типів документів (`_Reference34298`):**
- CMR: `0x9f54ce9f5b4daea911e69055bc05c919`
- ТТН: `0x87f1a8a804bd09d011e68ad725f58528`

**Приклад запиту — всі CMR за період:**
```sql
SELECT doc._Number, vt._Fld17895 AS DocDate, vt._Fld17896RRef AS StorageID
FROM _Document650_VT17890 vt WITH(NOLOCK)
JOIN _Document650 doc WITH(NOLOCK) ON vt._Document650_IDRRef = doc._IDRRef
WHERE vt._Fld17893RRef = 0x9f54ce9f5b4daea911e69055bc05c919
  AND vt._Fld17895 >= CAST('4025-09-30' AS datetime2)
  AND doc._Marked = 0
```

## Document647 — Статуси транспорту (253K рядків)

Live status updates вантажівок з посиланням на замовлення.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `StatusId` | ID (binary) |
| `_Number` | `StatusNumber` | Номер (Tr*) |
| `_Date_Time` | `StatusDate` | Дата (зміщення +2000) |
| `_Fld17636` | `Description` | Текстовий опис ("їде DE", "вантажиться в Глухуві") |
| `_Fld17640RRef` | `OrderID` | FK → Document650 (замовлення) |
| `_Fld17635RRef` | `TruckRef` | FK → транспорт |
| `_Fld17638` | `StatusDateTime` | Дата/час статусу |

## Document611 — Рахунки/Акти (80K рядків)

Фінансовий документ з номерами типу `AНо581(рах)`, `AДкN0004526`.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `InvoiceId` | ID (binary) |
| `_Number` | `InvoiceNumber` | Номер рахунку |
| `_Date_Time` | `InvoiceDate` | Дата (зміщення +2000) |
| `_Fld16522RRef` | `CustomerID` | FK → Reference123 (контрагент) |
| `_Fld16520` | `Amount1` | Сума (numeric) |
| `_Fld16523` | `Amount2` | Сума (numeric) |
| `_Fld16524` | `Amount3` | Сума (numeric) |
| `_Fld16533` | `Amount4` | Сума (numeric) |
| `_Fld16514` | `PeriodStart` | Початок періоду |
| `_Fld16515` | `PeriodEnd` | Кінець періоду |
| `_Fld16518RRef` | `CurrencyID` | FK → валюта |

## Document556 — Документи постачання (156K рядків)

Документи з номерами `AСн262(рах)`, `МВ*`. FK на контрагента (`_Fld13584RRef → Reference123`).

## Reference164 — Причини завершення договорів (7 рядків)

Довідник причин закриття договорів ("закінчення строку дії договору" тощо).

## Reference219 — Використовується для ідентифікації таблиці статей витрат

Довідник статей витрат з суфіксами (ПВ) = планові витрати, (ЗВ) = загальні/фактичні витрати.

## Прикріплені документи в 1С — Повна структура

Файли (CMR, ТТН, рахунки, акти) зберігаються в **трирівневій схемі**:

```
_Document650_VT17890 (реєстр файлів замовлення)
         │ _Fld17896RRef = FK на
         ▼
_Reference259 (Хранилище Дополнительной Информации — каталог файлів)
         │ _IDRRef = FK з
         ▼
_InfoRg34407 (Оцифровані Документи — шлях на Hetzner SFTP)
```

### _Reference259 — Хранилище Дополнительной Информации

Каталог файлів; кожен запис описує один фізичний файл.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `FileId` | ID запису сховища (binary 16) |
| `_Description` | `FileDesc` | Опис файлу (короткий коментар) |
| `_Fld3547` | `OrigName` | Оригінальна назва файлу (nvarchar 200) |
| `_Fld3548_TYPE/_RTRef/_RRRef` | `OwnerRef` | Composite ref → Document650 (документ-власник) |
| `_Fld3549` | `FileData` | **image/BLOB** — раніше тут зберігався файл повністю; зараз (після міграції на Hetzner) тут стаб `{"U"}` розміром 18 байт |
| `_Fld3550` | `FileData2` | Резервне BLOB-поле |
| `_Marked` | `Marked` | Прапор "помічено на видалення" |

**Формат `_Fld3549` коли файл ще в БД:**
```
10 bytes header
│
├── UTF-8 BOM (0xEF 0xBB 0xBF) + JSON заголовок з внутрішнім UUID
│    (~67 bytes total = "10+73=83" offset)
├── 12 bytes padding/розмір (варіативно)
└── Magic bytes + вміст файлу
    • PDF: `%PDF-` …                  до `%%EOF`
    • JPEG: 0xFF 0xD8 0xFF … 0xFF 0xD9
    • PNG: 0x89 0x50 0x4E 0x47 …
```

**Функція витягу (детекція за magic-bytes — PDF ПЕРШИМ, бо у PDF можуть бути JPEG вбудовано):**
```python
def detect_and_extract_file(data):
    pdf_idx = data.find(b'%PDF-')
    jpeg_idx = data.find(b'\xff\xd8\xff')
    png_idx  = data.find(b'\x89PNG\r\n\x1a\n')
    candidates = []
    if pdf_idx >= 0:  candidates.append((pdf_idx, 'application/pdf'))
    if jpeg_idx >= 0: candidates.append((jpeg_idx, 'image/jpeg'))
    if png_idx >= 0:  candidates.append((png_idx, 'image/png'))
    if not candidates: return None, None
    candidates.sort(key=lambda x: x[0])
    offset, mime = candidates[0]
    content = data[offset:]
    if mime == 'application/pdf':
        eof = content.rfind(b'%%EOF');  content = content[:eof+5] if eof>=0 else content
    elif mime == 'image/jpeg':
        eoi = content.rfind(b'\xff\xd9'); content = content[:eoi+2] if eoi>=0 else content
    return mime, content
```

### _InfoRg34407 — Оцифровані Документи (шлях на Hetzner)

Реєстр що мапить `Reference259._IDRRef` → шлях до файлу на Hetzner StorageBox.
~143 429 записів (близько до кількості файлів на Hetzner).

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Fld34408RRef` | `FileId` | FK → `_Reference259._IDRRef` |
| `_Fld34409` | `HetznerPath` | **Шлях на Hetzner** (ntext), напр. `\\Docs1C\40a88c40-7b85-11ed-8007-02b31cc3e401.pdf` |

### Фізичне сховище — Hetzner StorageBox

- **Хост:** `u506103-sub2.your-storagebox.de`
- **Порт:** `23` (SFTP)
- **Користувач:** `u506103-sub2`
- **Папка:** `/home/Docs1C/`
- **Назва файлу:** `UUID.ext` (UUID = частина з `_Fld34409`), формат: .pdf / .jpg / .jpeg / .png

### Повний SQL для витягу файлів замовлення

```sql
SELECT
    doc._Number                         AS Number,
    vt._Fld17895                        AS DocDate,
    r._Description                      AS FileDesc,
    CAST(r._Fld3547 AS NVARCHAR(200))   AS OrigName,
    r._Fld3549                          AS FileDataInDB,      -- звичайно stub {"U"}
    CAST(ir._Fld34409 AS NVARCHAR(500)) AS HetznerPath
FROM _Document650_VT17890 vt WITH(NOLOCK)
JOIN _Document650 doc     WITH(NOLOCK) ON vt._Document650_IDRRef = doc._IDRRef
LEFT JOIN _Reference259 r WITH(NOLOCK) ON r._IDRRef  = vt._Fld17896RRef AND r._Marked = 0
LEFT JOIN _InfoRg34407 ir WITH(NOLOCK) ON ir._Fld34408RRef = vt._Fld17896RRef
WHERE vt._Fld17893RRef = 0x9f54ce9f5b4daea911e69055bc05c919  -- CMR
  AND vt._Fld17895 >= CAST('4025-09-30' AS datetime2)        -- +2000 років
  AND doc._Marked = 0
```

### Приклад скачування через paramiko

```python
import paramiko
t = paramiko.Transport(('u506103-sub2.your-storagebox.de', 23))
t.connect(username='u506103-sub2', password='<pwd>')
sftp = paramiko.SFTPClient.from_transport(t)
basename = hetzner_path.replace('\\', '/').rsplit('/', 1)[-1]  # 'UUID.ext'
with sftp.file(f'/home/Docs1C/{basename}', 'rb') as f:
    content = f.read()
```

### Робочий приклад повного пайплайну

Дивитись `/Zvit_TTN_CMR_ACT/zvit_cmr_files.py` — готовий скрипт:
SQL → визначення джерела (БД vs Hetzner) → стиснення JPEG (PIL) → HTML з base64-вбудованими файлами.

## _Document650_VT34300 — Необхідні документи замовлення

Список документів, які вимагаються для закриття замовлення. 1820 рядків.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення |
| `_LineNo34301` | `LineNumber` | Номер рядка |
| `_Fld34302RRef` | `DocTypeID` | Тип документу (FK → `_Reference34298`) |
| `_Fld34303` | `Copies` | Кількість примірників (numeric) |

**Типи документів (_Reference34298):** "Рахунок", "Акт виконаних робіт", "CMR (з підписом та печаткою водія...)"

## _Document650_VT17898 — Температурний режим

Температурні вимоги та записи для вантажів. 4939 рядків.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення |
| `_LineNo17899` | `LineNumber` | Номер рядка |
| `_Fld17900` | `TempDate` | Дата запису температури (datetime, зміщення +2000) |
| `_Fld17901` | `Temperature` | Значення температури (nvarchar 20). Приклади: "+60", "+46" — градуси Цельсія |
| `_Fld17902` | `TempNote` | Примітка до температури (nvarchar 20, зазвичай порожнє) |

## _Document650_VT32476 — Послуги перевезення

Табличний рядок для розрахунку рахунку: тип послуги × кількість × ціна = сума. ~42K рядків.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Document650_IDRRef` | `OrderId` | FK на замовлення |
| `_LineNo32477` | `LineNumber` | Номер рядка |
| `_Fld32481RRef` | `ServiceTypeID` | Тип послуги (FK → `_Reference152`). Назва послуги |
| `_Fld32482` | `Flag` | Прапор (binary 1) |
| `_Fld32483` | `Quantity` | Кількість (км або тонни) |
| `_Fld32484` | `UnitPrice` | Ціна за одиницю |
| `_Fld32485` | `TotalAmount` | Сума = `_Fld32483 × _Fld32484` |
| `_Fld32486RRef` | `CurrencyOrRef` | Валюта або інший reference |
| `_Fld32487` | `AdditionalAmount` | Додаткова сума (ПДВ або нетто) |

**Топ типів послуг (_Reference152):**
- "Транспортні перевезення" (15779 рядків)
- "Транспортні перевезення по Україні" (6469)
- "Міжнародне перевезення вантажу автомобільним транспортом" (5266)

**Приклад:** `1726 км × 27.36 грн/км = 47,223.36 грн`

### Reference162 — Компанії-перевізники (наші організації)

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `OrgId` | ID (binary) |
| `_Description` | `OrgName` | Назва організації |

**Відомі значення:** "Стеллар МВ, ТОВ" (60699), "Трімекс" (20011), "Форланд" (935), "ТС Логістик" (153)

### Reference177 — Відповідальні менеджери

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `ManagerId` | ID (binary) |
| `_Description` | `ManagerName` | ПІБ менеджера/логіста |

~60 унікальних менеджерів. Топ: "Темощук Мар'яна Андріївна" (24695), "Гарасівка Анатолій" (7693).

### Reference152 — Типи послуг перевезення

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `ServiceTypeId` | ID (binary) |
| `_Description` | `ServiceTypeName` | Назва типу послуги |

### Reference34298 — Типи документів

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `DocTypeId` | ID (binary) |
| `_Description` | `DocTypeName` | Назва типу документу |

## _InfoRg23603 — Сведения о транспортном средстве (680 рядків)

Регістр відомостей з технічними характеристиками кожного ТЗ (тягачі + причепи). Один запис на кожне ТЗ. Ключ — `_Fld23607` (держ. номер).

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_Fld23604RRef` | `VehicleRef` | FK на Reference (binary) |
| `_Fld23607` | `PlateNumber` | Держ. номер (nvarchar, з пробілами — RTRIM!) |
| `_Fld23608RRef` | `ModelRef` | FK → Reference286 (модель/тип ТЗ) |
| `_Fld23612` | `EngineNumber` | Номер двигуна |
| `_Fld23615` | `VIN` | VIN / Номер шассі |
| `_Fld23633` | `Year` | Рік випуску (numeric, без зміщення) |
| `_Fld23634` | `RegistrationDate` | Дата реєстрації (зміщення +2000) |
| `_Fld23640` | `TankVolume` | Об'єм баку (л) |
| `_Fld23642` | `TareWeight` | **Собственний вес, тн.** (99% fill, діапазон 0.15–35 т) |
| `_Fld26723` | `EnginePower` | Потужність двигуна (к.с.) |
| `_Fld26970` | `AxleCount` | Кількість осей |
| `_Fld32314` | `DimensionA` | Габарит A (м) |
| `_Fld32315` | `DimensionB` | Габарит B (м) |
| `_Fld33852` | `MaxWeight` | Макс. дозволена маса (т) |
| `_Fld34313` | `SentGeoLinko` | Sent-Geo [Linko] ID |
| `_Fld34315` | `SentGeoSecondary` | Sent-Geo (доп.) ID |

**Використання для отримання ваги ТЗ:**
```sql
SELECT RTRIM(_Fld23607) AS plate, _Fld23642 AS tare_weight
FROM dbo._InfoRg23603
WHERE _Fld23642 > 0
```

## Поширені помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| Дати в майбутньому | 1С додає 2000 р. | Додай +2000 до фільтру дати |
| Порожній результат за ID | ID передано як string | Конвертуй: `bytes.fromhex(id_hex)` |
| Зайві пробіли в номерах | `_Number` має пробіли | `LTRIM(RTRIM(d._Number))` |
| `_Posted = NULL` документи | Непроведені записи | Додай `WHERE d._Posted = 0x01` |
| Полімофне поле | `_Fld17681` — це `_TYPE + _RTRef + _RRRef` | JOIN тільки по `_RRRef` частині |
| `ntext` поля не підтримують `RTRIM`/`LTRIM` | Деякі Reference поля мають тип `ntext` | Обгортай в `CAST(field AS NVARCHAR(500))` перед TRIM |

## Змінні середовища (.env)

```
DB_SERVER=<ip або hostname SQL Server>
DB_NAME=work
DB_USER=<користувач>
DB_PASSWORD=<пароль>
DB_ENCRYPT=yes
DB_TRUST_CERT=yes
```

## Нові довідники (дослідження 2026-03-28)

### Reference162 — Організації (`Справочник.Организации`)

Наші юридичні особи (перевізники). 5+ записів.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `OrgId` | ID (binary) |
| `_Description` | `OrgName` | Назва організації |

**Приклади:** Стеллар МВ (ТОВ), Litrans, Luxsolgroup OU, Алстар (ФГ)

### Reference177 — Менеджери/Користувачі 1С

60+ менеджерів. Використовується в Document650._Fld17686RRef (відповідальний менеджер).

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `ManagerId` | ID (binary) |
| `_Description` | `ManagerName` | ПІБ менеджера |

### Reference85 — Договори/Контракти

1318+ договорів. FK від Document650._Fld17688RRef.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `ContractId` | ID (binary) |
| `_Description` | `ContractName` | Назва договору |

### Reference38 — Валюти

5 валют: грн, EUR, PLN, USD, BGN. FK від Document650._Fld17693RRef.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `CurrencyId` | ID (binary) |
| `_Description` | `CurrencyName` | Назва валюти |

### Reference315 — Типи причепів/ТЗ

16 типів. FK від Document650._Fld17718RRef.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `TrailerTypeId` | ID (binary) |
| `_Description` | `TrailerTypeName` | Назва типу |

**Приклади:** Напівпричіп-цистерна, TDI-контейнер, Генератор

### Reference208 — Контактні особи клієнтів

69+ контактів. FK від Document650._Fld17720RRef.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `ContactPersonId` | ID (binary) |
| `_Description` | `ContactPersonName` | ПІБ |

### Reference271 — Групи/Типи вантажів

18 типів. FK від Document650._Fld17728RRef.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `CargoGroupId` | ID (binary) |
| `_Description` | `CargoGroupName` | Назва |

**Приклади:** Патока/Меляса/Глюкоза, Cocoa Mass West, NFC ORANGE

### Reference217 — Типи оплати

3 типи. FK від Document650._Fld32632RRef (50% fill).

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `PaymentTypeId` | ID (binary) |
| `_Description` | `PaymentTypeName` | Назва |

### Reference152 — Номенклатура (Послуги/Товари)

Використовується в VT32476 та VT17871.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `ItemId` | ID (binary) |
| `_Description` | `ItemName` | Назва |

**Приклади:** Транспортні перевезення по Україні (км), Adblue, ADR комплект

### Reference34298 — Типи документів (чеклист)

10 типів документів. Використовується в VT34300.

| SQL поле | Псевдонім | Опис |
|----------|-----------|------|
| `_IDRRef` | `DocTypeId` | ID (binary) |
| `_Description` | `DocTypeName` | Назва типу документа |

**Приклади:** CMR, Рахунок, Акт виконаних робіт, вагова квитанція, ТТН (оригінал)

## Нові поля Document650 (дослідження 2026-03-28)

Поля що НЕ витягуються в sync_1c.py, але мають дані:

| SQL поле | Тип | Fill% | Опис |
|----------|-----|-------|------|
| `_Fld17686RRef` | FK→Ref177 | 100% | **Менеджер** (відповідальний) |
| `_Fld17688RRef` | FK→Ref85 | 100% | **Договір/Контракт** з клієнтом |
| `_Fld17693RRef` | FK→Ref38 | 100% | **Валюта** документа (грн/EUR/PLN/USD) |
| `_Fld17679RRef` | FK→Ref162 | 100% | **Організація** (наша юр. особа) |
| `_Fld17722RRef` | FK→Ref332 | 99.1% | **Країна відправлення** |
| `_Fld17723RRef` | FK→Ref332 | 99.1% | **Країна призначення** |
| `_Fld17728RRef` | FK→Ref271 | 95.6% | **Група вантажу** |
| `_Fld17718RRef` | FK→Ref315 | 94% | **Тип причепа** |
| `_Fld17720RRef` | FK→Ref208 | 94.8% | **Контактна особа клієнта** |
| `_Fld17711RRef` | FK→Ref173 | 100% | **Підрозділ/Відділ** |
| `_Fld17716` | datetime | 97.8% | **Дата завантаження** (планова) |
| `_Fld27200` | datetime | 97.7% | **Дата розвантаження** (планова) |
| `_Fld17734` | nvarchar(100) | 74.8% | **Ціноутворення** ("3900 EUR", "105 €/т") |
| `_Fld33985` | binary(1) | 71% | **Харчовий вантаж** (bool) |
| `_Fld17742` | ntext | 89.5% | **Умови перевезення** |
| `_Fld17743` | ntext | 87.1% | **Особливі відмітки** |
| `_Fld17744` | ntext | 81.6% | **Правила безпеки** на заводах |
| `_Fld17745` | ntext | 84.4% | **Заборонені вантажі** |
| `_Fld17768` | numeric | 81.1% | **Порожній пробіг** (км, агреговане) |
| `_Fld17770` | numeric | 84.6% | **Пробіг з вантажем** (км) |
| `_Fld17774` | numeric | 83.3% | **Відхилення по км** (від'ємне=перевитрата) |
| `_Fld27138` | nvarchar(100) | 58.2% | **Нормативний час розвантаження** ("9 год") |
| `_Fld27424` | nvarchar(500) | 55.8% | **Примітки відхилення по км** |
| `_Fld27425` | nvarchar(500) | 42.3% | **Примітки про затримки** |
| `_Fld17715` | nvarchar(80) | 29.9% | **Зовнішній номер заявки** (TMP*, TR*) |
| `_Fld17684` | nvarchar(100) | 18.4% | **ID замовлення клієнта** |
| `_Fld17725` | nvarchar(500) | 19.3% | **Телефон завантаження** |
| `_Fld17726` | nvarchar(500) | 21.5% | **Телефон розвантаження** |
| `_Fld33870` | datetime | 18.4% | **Факт: початок завантаження** |
| `_Fld33871` | datetime | 18.2% | **Факт: кінець завантаження** |
| `_Fld32632RRef` | FK→Ref217 | 50.1% | **Тип оплати** |
| `_Fld34245` | ntext | 3.3% | **Формат авізації** |
| `_Fld34246` | ntext | 1.8% | **Вимоги до документів** після рейсу |
| `_Fld34238` | nvarchar(50) | 0.4% | **Графік роботи завантаження** |
| `_Fld34239` | nvarchar(50) | 0.5% | **Графік роботи розвантаження** |

## Нові VT таблиці Document650 (дослідження 2026-03-28)

### _Document650_VT32476 — Деталізація послуг перевезення (42K рядків)

Позиції рахунку/акту по замовленню. Кількість x Ціна = Сума.

| SQL поле | Опис |
|----------|------|
| `_Document650_IDRRef` | FK на замовлення |
| `_LineNo32477` | Номер рядка |
| `_Fld32481RRef` | FK → Reference152 (номенклатура) |
| `_Fld32483` | Кількість |
| `_Fld32484` | Ціна за одиницю |
| `_Fld32485` | Сума |
| `_Fld32487` | ПДВ |

### _Document650_VT17871 — Доходи/Виставлені послуги (5.4K рядків)

| SQL поле | Опис |
|----------|------|
| `_Document650_IDRRef` | FK на замовлення |
| `_LineNo17872` | Номер рядка |
| `_Fld17876RRef` | FK → Reference152 (номенклатура) |
| `_Fld17878` | Кількість |
| `_Fld17879` | Ціна |
| `_Fld17880` | Сума |

### _Document650_VT17898 — Температурний журнал (4.9K рядків)

| SQL поле | Опис |
|----------|------|
| `_Document650_IDRRef` | FK на замовлення |
| `_Fld17900` | Дата показника (зміщення +2000) |
| `_Fld17901` | Значення ("+60", "+46" — температура) |
| `_Fld17902` | Додатковий параметр |

### _Document650_VT34300 — Чеклист документів (1.8K рядків)

| SQL поле | Опис |
|----------|------|
| `_Document650_IDRRef` | FK на замовлення |
| `_Fld34302RRef` | FK → Reference34298 (тип: CMR, Рахунок, Акт) |
| `_Fld34303` | Кількість примірників |

### Повний список VT таблиць Document650

| Таблиця | Рядків | Статус |
|---------|--------|--------|
| VT17775 | ~80K | Маршрути (EmptyKm/LoadedKm) — **витягуємо** |
| VT17818 | ~80K | Етапи/Рейси — **витягуємо** (CargoName, Weight) |
| VT17903 | ~2M | Нормативні витрати — **описано в скілі** |
| VT17859 | ~76K | Витрати рейсу — **описано в скілі** |
| VT17841 | ~64K | Послуги/Матеріали — **описано в скілі** |
| VT17890 | ~151K | Точки маршруту — **описано в скілі** |
| VT32476 | 42K | Деталізація послуг — **НОВЕ** |
| VT17871 | 5.4K | Доходи — **НОВЕ** |
| VT17898 | 4.9K | Температурний журнал — **НОВЕ** |
| VT34300 | 1.8K | Чеклист документів — **НОВЕ** |
| VT34054 | 188 | Додаткові витрати (мало даних) |
| VT34485 | 22 | Секції цистерни (мало даних) |
| VT34304 | 1 | Практично порожня |
| VT17803 | 0 | Порожня |
| VT17808 | 0 | Порожня |
| VT17852 | 0 | Порожня |
| VT17883 | 0 | Порожня |

---

## Document684 — Шляховий лист (Waybill)

**Таблиця:** `_Document684` (110,794 рядків)
**Призначення:** Маршрутний/шляховий лист з розрахунком палива та витрат

### КРИТИЧНА ОСОБЛИВІСТЬ: Trimex vs Stellar (верифіковано 2026-04-07)

- **Stellar (МВ\*):** Один запис = один рейс. Всі суми в **UAH**.
- **Trimex (Tr\*):** КІЛЬКА записів з однаковим номером (по одному за рік). Всі суми в **EUR**.
- Організацію визначати через `_Fld19484RRef` → Reference162 ("Стеллар МВ, ТОВ" або "Трімекс")

### Ключові поля шапки

| SQL поле | Опис | Тип |
|----------|------|-----|
| `_IDRRef` | ID документа | binary(16) |
| `_Number` | Номер ("МВ0011019" / "Tr000000680") | nvarchar(11) |
| `_Date_Time` | Дата (+2000 offset) | datetime |
| `_Posted` | Проведено (0x01) | binary(1) |
| `_Fld19447RRef` | Статус → Enum1201 | binary(16) |
| `_Fld19449RRef` | FK → Document650 (замовлення) | binary(16) |
| `_Fld19452_RRRef` | Тягач → Reference167 (RTRef=0xA7) | binary(16) |
| `_Fld19453_RRRef` | Причіп → Reference167 | binary(16) |
| `_Fld19480RRef` | Водій → Reference254 | binary(16) |
| `_Fld19484RRef` | Організація → Reference162 | binary(16) |
| `_Fld32554` | Затверджено (bool) | binary(1) |

### Поля пробігу

| SQL поле | Опис | Тип |
|----------|------|-----|
| `_Fld19457` | Порожній пробіг (км) | numeric |
| `_Fld19460` | Вантажний пробіг (км) | numeric |
| `_Fld32538` | Загальний пробіг (км) | numeric |
| `_Fld32539` | Загальний пробіг копія (=_Fld32538) | numeric |
| `_Fld19485` | Навантажений km для СЕГМЕНТУ (Trimex) | numeric |
| `_Fld19486` | Порожній km для СЕГМЕНТУ (Trimex) | numeric |

### Паливні поля (верифіковано через VT19493 cross-reference 2026-04-07)

| SQL поле | Реальне значення | Stellar валюта | Trimex валюта | Перевірено |
|----------|-----------------|---------------|--------------|-----------|
| `_Fld33823` | Норма витрати палива (л/100км) — загальна | — | — | ✓ |
| `_Fld33824` | Фактична витрата (л/100км) | — | — | ✓ |
| `_Fld34281` | Скоригована норма (л/100км) — нижча на 15-20% | — | — | ✓ |
| `_Fld19487` | **Diesel cost З ПДВ** | **UAH (грн)** | **EUR** | ✓✓✓ |
| `_Fld33825` | **AdBlue cost З ПДВ** | **UAH (грн)** | **UAH (грн)** | ✓✓✓ |
| `_Fld34286` | **Diesel cost БЕЗ ПДВ** | **UAH (грн)** | **EUR** | ✓✓✓ |
| `_Fld34282` | **AdBlue cost БЕЗ ПДВ** | **UAH (грн)** | **UAH (грн)** | ✓✓✓ |
| `_Fld26714` | Невідоме — ratio до diesel_vat = 18-49, НЕ курс | ? | ? | — |
| `_Fld34288` | Невідоме — пропорційне до _Fld26714 | ? | ? | — |

**КРИТИЧНО: Trimex AdBlue в грн, а Diesel в EUR!** Це підтверджено через VT19493 `_Fld19497RRef → Reference38`:
- Stellar VT19493: "Пальне" = **грн**, "AD Blue" = **грн**
- Trimex VT19493: "Пальне" = **EUR**, "AD Blue" = **грн**

**ПДВ перевірка:** `_Fld34286 * 1.20 = _Fld19487` (точність до 1 коп) ✓

**УВАГА:** Поля "стан палива на початок/кінець відрізку" (fuel_level_start/end) **НЕ ЗНАЙДЕНО** в Document684.

### Інші поля

| SQL поле | Опис | Тип |
|----------|------|-----|
| `_Fld19463` | Ціна палива? (92.00 для Stellar, 2.15 для Trimex — константа по організації) | numeric |
| `_Fld19464` | Ціна одиниці (EUR/L?) | numeric |
| `_Fld19465` | Ціна одиниці (EUR/L?) — дублює _Fld19464 | numeric |
| `_Fld19466` | Невідоме (284.43 для прикладу) | numeric |
| `_Fld19481` | Зарплата планова | numeric |
| `_Fld19482` | Зарплата фактична | numeric |
| `_Fld32552` | Кількість рейсів | numeric |
| `_Fld34283` | Ціна одиниці (змінна) | numeric |

### Enum1201 — Статуси шляхового листа

| EnumOrder | Значення |
|-----------|----------|
| 0 | Відкритий |
| 1 | Закритий |
| 2 | (невідомий) |

### VT таблиці Document684

| Таблиця | Рядків | Опис |
|---------|--------|------|
| `_Document684_VT19493` | 4,150,677 | **Довідка-розрахунок** — статті витрат (план/факт). Ключ: `_Fld19496RRef` → Reference219. `_Fld19499` = сума З ПДВ. `_Fld34287` = сума БЕЗ ПДВ. |
| `_Document684_VT32519` | 87,970 | Контроль платних доріг по країнах |
| `_Document684_VT32555` | 46,653 | Маршрути рейсу → Reference283 |

### VT19493 зв'язок з header полями (підтверджено)

- `_Fld19487` (header) = VT рядок "Пальне для вантажних ТЗ (ПВ)" → `_Fld19499` (факт з ПДВ)
- `_Fld33825` (header) = VT рядок "AD Blue" → `_Fld19499` (факт з ПДВ)
- `_Fld34286` (header) = VT рядок "Пальне" → `_Fld34287` (факт без ПДВ)
- `_Fld34282` (header) = VT рядок "AD Blue" → `_Fld34287` (факт без ПДВ)

### Document392 — Подорожній лист (розбивка по сегментах маршруту)

**Таблиця:** `_Document392` (93,628 рядків)
**Зв'язок:** `_Fld6396_RRRef` → Document650 (поліморфне, RTRef=0x0000028a)

#### Ключові поля шапки Document392

| SQL поле | Опис |
|----------|------|
| `_Fld6380` | Курс EUR/UAH (напр. 43.58) або 1.0 для UAH-рейсів |
| `_Fld6388` | **"Сума виїзду"** = загальна сума EUR-сегментів рейсу (в EUR) |
| `_Fld6378RRef` | Контрагент → Reference123 |
| `_Fld6396_RRRef` | FK → Document650 (замовлення) |

#### VT6434 — Рядки рахунку по сегментах маршруту

| SQL поле | Опис |
|----------|------|
| `_Fld6436` (ntext) | Назва сегменту: "Димер - Ягодин (UA)/Дорохуськ (PL) (545 км.)" |
| `_Fld6437` | Кількість (зазвичай 1.000) |
| `_Fld6438` | Ціна сегменту (EUR або UAH) |
| `_Fld6439` | Сума сегменту (= qty × ціна) |
| `_Fld6441` | ПДВ (тільки для UAH-рядків: total × 0.2/1.2) |
| `_Fld6440RRef` | Тип сегменту → Enum1070 |
| `_Fld6442RRef` | Тип послуги → Reference152 ("Міжнародне перевезення") |

#### Enum1070 — Типи сегментів

| EnumOrder | Значення |
|-----------|----------|
| 0 | Іноземний/EUR сегмент |
| 2 | UAH/Україна сегмент |
| 5 | Простій |

**УВАГА:** VT6434 — це розбивка **вартості рейсу** по сегментах, НЕ палива! Паливо по сегментах в 1С не зберігається.

#### SQL приклад: сегменти рейсу з Document392

```sql
SELECT
    LTRIM(RTRIM(d._Number)) AS invoice_num,
    DATEADD(YEAR, -2000, d._Date_Time) AS invoice_date,
    d._Fld6380 AS eur_rate,
    d._Fld6388 AS exit_sum_eur,
    vt._LineNo6435 AS line_no,
    CAST(vt._Fld6436 AS NVARCHAR(500)) AS segment_name,
    vt._Fld6439 AS total_amount,
    vt._Fld6441 AS vat_amount,
    e1070._EnumOrder AS segment_type,
    LTRIM(RTRIM(d650._Number)) AS order_num
FROM dbo._Document392 d
JOIN dbo._Document392_VT6434 vt ON vt._Document392_IDRRef = d._IDRRef
LEFT JOIN dbo._Enum1070 e1070 ON vt._Fld6440RRef = e1070._IDRRef
LEFT JOIN dbo._Document650 d650 ON d._Fld6396_RRRef = d650._IDRRef
WHERE d._Posted = 0x01
  AND d._Date_Time > DATEADD(YEAR, 2000, DATEADD(DAY, -90, GETDATE()))
ORDER BY d._Date_Time DESC, vt._LineNo6435
```

### SQL приклад: витрата палива по замовленню (ПРАВИЛЬНИЙ маппінг)

```sql
SELECT
    LTRIM(RTRIM(d684._Number)) AS waybill_number,
    DATEADD(YEAR, -2000, d684._Date_Time) AS waybill_date,
    e1201._EnumOrder AS status_enum,
    LTRIM(RTRIM(d650._Number)) AS order_number,
    r162._Description AS organization_name,  -- "Стеллар МВ, ТОВ" або "Трімекс"
    d684._Fld19457 AS km_empty,
    d684._Fld19460 AS km_loaded,
    d684._Fld32538 AS km_total,
    d684._Fld33823 AS fuel_norm_l100,
    d684._Fld33824 AS fuel_actual_l100,
    d684._Fld34281 AS fuel_adj_norm_l100,
    d684._Fld19487 AS diesel_cost_with_vat,   -- UAH (Stellar) / EUR (Trimex)!
    d684._Fld33825 AS adblue_cost_with_vat,   -- UAH (грн) для обох організацій!
    d684._Fld34286 AS diesel_cost_no_vat,     -- UAH (Stellar) / EUR (Trimex)!
    d684._Fld34282 AS adblue_cost_no_vat,     -- UAH (грн) для обох організацій!
    r254._Description AS driver_name,
    r167._Description AS truck_name
FROM dbo._Document684 d684
LEFT JOIN dbo._Enum1201 e1201 ON d684._Fld19447RRef = e1201._IDRRef
LEFT JOIN dbo._Document650 d650 ON d684._Fld19449RRef = d650._IDRRef
LEFT JOIN dbo._Reference254 r254 ON d684._Fld19480RRef = r254._IDRRef
LEFT JOIN dbo._Reference167 r167 ON d684._Fld19452_RRRef = r167._IDRRef
LEFT JOIN dbo._Reference162 r162 ON d684._Fld19484RRef = r162._IDRRef
WHERE d684._Posted = 0x01
  AND d684._Date_Time >= DATEADD(YEAR, 2000, DATEADD(DAY, -90, GETDATE()))
ORDER BY d684._Date_Time DESC
```

---

## DDD-картки тахографа водіїв (Чіп) — `_InfoRg23405`

Регістр відомостей "Документи фізичних осіб" — зберігає всі типи документів водіїв (медична, права, чіп тощо). Для DDD-карток (16-char тахограф ID типу `UAD0000005M0Y001`) фільтр по виду документа.

### Структура `_InfoRg23405`

| Поле | Тип | Опис |
|------|-----|------|
| `_Fld23406RRef` | binary(16) | FK → `_Reference254._IDRRef` (водій) |
| `_Fld23407RRef` | binary(16) | FK → `_Reference265._IDRRef` (вид документа) |
| `_Fld23408` | nvarchar(14) | **Серія** (для UA чіпів = `'UAD'`) |
| `_Fld23409` | nvarchar(14) | **Номер** (13 символів — `'0000083854000'`) |
| `_Fld23410` | datetime (offset +2000) | Дата видачі |
| `_Fld23411` | datetime (offset +2000) | Дата закінчення |

### IDs видів документа "Чіп" у `_Reference265`

```
0x835aba8f5a3507c811e71b5f6e0ead03  — "Чіп"      (код 00017, основний)
0x927bbc01eacc65be11eaca8dd70d1df0  — "Чіп 1"    (код 00055)
0xa9d002b31cc3e40111eebab5b242e740  — "чіп 3"    (код 00076)
```

### Витягнути актуальний чіп для всіх водіїв

```sql
WITH ranked AS (
    SELECT
        ir._Fld23406RRef AS driver_ref,
        RTRIM(ir._Fld23408) + RTRIM(ir._Fld23409) AS chip_full,
        ROW_NUMBER() OVER (PARTITION BY ir._Fld23406RRef ORDER BY ir._Fld23411 DESC) AS rn
    FROM dbo._InfoRg23405 ir
    WHERE ir._Fld23407RRef IN (
        0x835aba8f5a3507c811e71b5f6e0ead03,
        0x927bbc01eacc65be11eaca8dd70d1df0,
        0xa9d002b31cc3e40111eebab5b242e740
    )
)
SELECT r254._Description AS driver_name, ranked.chip_full
FROM ranked
JOIN dbo._Reference254 r254 ON ranked.driver_ref = r254._IDRRef
WHERE rn = 1 AND LEN(chip_full) = 16
```

### Gotchas

- **`_Fld23408 + _Fld23409`** має бути 16 символів. Іноді оператор записує весь номер у `_Fld23409` без серії — тоді len = 14. Фільтрувати `LEN(chip_full) = 16`.
- **Один водій може мати кілька чіпів** (старий expired + новий). Використовувати `ROW_NUMBER() PARTITION BY ORDER BY _Fld23411 DESC`.
- **Сирі дати** мають offset +2000 років (стандарт 1С). Використовувати `DATEFROMPARTS(YEAR()-2000, MONTH(), DAY())` для конвертації.
- **Покриття:** ~58% активних водіїв (197/341 у проді 2026-04). Решта — без заповненого чіпа в 1С.
- **DDD-картка = той самий 16-char код що приходить у LINQO SSE** як `inputs.device_inputs.first_driver_id`. Це primary identifier маппінгу 1С↔LINQO.

---

## Маржа / рентабельність зі схеми `pbi` (передраховано 1С)

1С зберігає **готову** (передраховану) маржу/рентабельність по рейсах у **окремій схемі `pbi`** (не `dbo`). Це джерело BI-звітів (Power BI, аналітик Анна Максимова). **Читати цю маржу, а НЕ рахувати власноруч** — числа вже узгоджені з обліком (дохід − витрати − ЗП водія).

> ⚠️ Інша схема (`pbi`, не `dbo`) → інші правила: **`TargetDate` БЕЗ зсуву +2000**, `OrderRef` = **UPPERCASE hex-рядок** (не binary). Не плутати з правилами `dbo`.

### Об'єкти схеми `pbi`

38 об'єктів. **4 базові таблиці:** `TargetTableFact` (ФАКТ), `TargetTablePlan` (ПЛАН), `TargetTableReal` (**порожня** — не юзати), `FreeCars`. Решта — VIEW (зокрема `v_PlanExpenses`).

```sql
SELECT TABLE_NAME, TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'pbi' ORDER BY TABLE_NAME;
```

### `pbi.TargetTableFact` / `pbi.TargetTablePlan` — структура (16 колонок, ідентична)

| Колонка | Тип | Опис |
|---------|-----|------|
| `OrderRef` | varchar | **UPPERCASE hex** від `Document650._IDRRef` (32 символи). Може бути **NULL** (≈20% рядків = дні простою тягача без замовлення) |
| `TargetDate` | datetime | День рейсу. **БЕЗ зсуву +2000** (реальний рік 2024-2026) |
| `TruckRef` | varchar | hex тягача (`0000…0` коли немає) |
| `DriverRef` | varchar | hex водія |
| `StatementRef` | varchar | hex відомості |
| `DayPart` | numeric | Частка дня (`0.50` = пів дня) — рейс розбито по днях |
| `IncomePerDay` | numeric | Дохід / день (EUR) |
| `ExpensesPerDayWithoutSalary` | numeric | Витрати / день БЕЗ ЗП водія (EUR) |
| `DriverSalaryPerDay` | numeric | ЗП водія / день (EUR) |
| **`MarginPerDay`** | numeric | **Маржа / день (EUR без ПДВ)** ← головна метрика |
| `BreakEvenPointPerDay` | numeric | Точка беззбитковості / день |
| `QuotaPerDay` | numeric | Квота / день |
| `MainManagerRef` / `CurManagerRef` | varchar | Менеджери (hex → Reference123 співробітники) |

**Формула (перевірено арифметично):**
```
MarginPerDay = IncomePerDay − ExpensesPerDayWithoutSalary − DriverSalaryPerDay
```
(«WithoutSalary» стосується лише колонки витрат — у `MarginPerDay` ЗП вже віднята.)

**DAX-відповідність** (від аналітика):
- `'TargetTable'[MarginePerDayPlanKey-VAT]` = `pbi.TargetTablePlan.MarginPerDay` (план)
- `'TargetTable'[MarginePerDayFactSalary-VAT]` = `pbi.TargetTableFact.MarginPerDay` (факт)

### ГРАНУЛЯРНІСТЬ — критично

**1 рядок = (OrderRef × TargetDate × Truck × Driver × Statement)**, тобто **рейс розбитий ПО ДНЯХ** (по рядку на кожен день рейсу). `OrderRef` **НЕ унікальний**.

```sql
-- Перевірка: total >> distinct_orders → рядок ≠ рейс
SELECT COUNT(*) AS total, COUNT(DISTINCT OrderRef) AS distinct_orders
FROM pbi.TargetTableFact;
-- приклад: 136177 total / 18661 distinct orders
```

- **Маржа ЗА РЕЙС:** `SUM(MarginPerDay) GROUP BY OrderRef`. `DayPart` уже зашитий у per-day суми — **повторно множити НЕ треба**.
- **Маржа НА ДЕНЬ за рейс (нормалізована):** `SUM(MarginPerDay) / NULLIF(SUM(DayPart), 0)`.
- **Майбутні `TargetDate`** (forecast-рядки, `Expenses=0`) присутні до кінця місяця → фільтрувати `TargetDate < CAST(GETDATE() AS date)`, інакше маржа спотвориться.

### JOIN `OrderRef` ↔ Document650 / TMS Load

`OrderRef` = **UPPERCASE hex** = `hex(Document650._IDRRef)`.

| Напрямок | Конвертація |
|----------|-------------|
| pbi → `dbo._Document650` (SQL) | `JOIN dbo._Document650 d ON d._IDRRef = CONVERT(binary(16), f.OrderRef, 2)` |
| pbi OrderRef → bytes (Python) | `bytes.fromhex(order_ref)` |
| pbi → TMS Postgres `Load.id_1c` | `lower(OrderRef) = Load.id_1c` (Load.id_1c — **lowercase**!) |

### `pbi.v_PlanExpenses` — собівартість / подача (порожній пробіг)

VIEW з розкладкою витрат по статтях. Ключове для аналізу **подачі (порожнього пробігу)**.

| Колонка | Опис |
|---------|------|
| `OrderRef` | UPPERCASE hex (той самий формат) |
| `Dates` | дата (БЕЗ +2000) |
| `ExpensesItemRef` | FK → Reference219 (стаття витрат) |
| **`ArriveCost`** | `bit`: **True = витрата ПОДАЧІ/маршруту** (гейт порожнього пробігу) |
| `FuelAmountPlan` | планове паливо (л) |
| `SumFact` | сума **UAH** (великі числа) |
| **`SumManagerial`** | сума **EUR** (управлінська) ← юзати для EUR-аналізу |
| `VAT` / `VATManagerial` | ПДВ |

> ⚠️ Дві валюти: `SumFact`=UAH, `SumManagerial`=EUR. **Не змішувати.**

### Готові SQL (усі реально виконані проти живої 1С)

```sql
-- (1) Маржа/день по рейсах конкретного контрагента (Fact)
--     param ? = bytes.fromhex(customer_id_1c), напр. Славутич = a87802b31cc3e40111ed01e8fc39f860
SELECT LTRIM(RTRIM(d._Number))           AS order_num,
       f.TargetDate, f.DayPart,
       f.IncomePerDay, f.ExpensesPerDayWithoutSalary,
       f.DriverSalaryPerDay, f.MarginPerDay
FROM pbi.TargetTableFact f
JOIN dbo._Document650 d ON d._IDRRef = CONVERT(binary(16), f.OrderRef, 2)
WHERE d._Fld17681_RRRef = ?              -- замовник (FK → Reference123)
  AND f.TargetDate >= '2025-06-01'       -- реальний рік, БЕЗ +2000
  AND f.TargetDate <  CAST(GETDATE() AS date);

-- (2) Маржа АГРЕГОВАНА за рейс (сума по днях) + маржа/день
SELECT f.OrderRef,
       SUM(f.MarginPerDay)                           AS margin_total_eur,
       SUM(f.DayPart)                                AS days,
       SUM(f.MarginPerDay)/NULLIF(SUM(f.DayPart),0)  AS margin_per_day_eur
FROM pbi.TargetTableFact f
WHERE f.OrderRef IS NOT NULL
GROUP BY f.OrderRef;

-- (3) План vs Факт по одному рейсу
SELECT 'plan' AS src, SUM(MarginPerDay) m FROM pbi.TargetTablePlan WHERE OrderRef = ?
UNION ALL
SELECT 'fact', SUM(MarginPerDay)        FROM pbi.TargetTableFact WHERE OrderRef = ?;

-- (4) Собівартість подачі (порожній пробіг) по рейсах контрагента, EUR
SELECT LTRIM(RTRIM(d._Number)) AS order_num,
       SUM(CASE WHEN pe.ArriveCost = 1 THEN pe.SumManagerial ELSE 0 END) AS arrive_cost_eur,
       SUM(pe.SumManagerial) AS total_cost_eur
FROM pbi.v_PlanExpenses pe
JOIN dbo._Document650 d ON d._IDRRef = CONVERT(binary(16), pe.OrderRef, 2)
WHERE d._Fld17681_RRRef = ?
GROUP BY LTRIM(RTRIM(d._Number));
```

### Python-приклад (через backend `_get_1c_connection`)

```python
from app.services.sync_1c import _get_1c_connection  # backend/app/services/sync_1c.py:79

conn = _get_1c_connection()
cur = conn.cursor()

customer_id_1c = "a87802b31cc3e40111ed01e8fc39f860"   # Reference123._IDRRef як hex
cur.execute("""
    SELECT f.OrderRef,
           SUM(f.MarginPerDay)                          AS margin_total_eur,
           SUM(f.DayPart)                               AS days,
           SUM(f.MarginPerDay)/NULLIF(SUM(f.DayPart),0) AS margin_per_day_eur
    FROM pbi.TargetTableFact f
    JOIN dbo._Document650 d ON d._IDRRef = CONVERT(binary(16), f.OrderRef, 2)
    WHERE d._Fld17681_RRRef = ?
      AND f.TargetDate < CAST(GETDATE() AS date)
    GROUP BY f.OrderRef
""", bytes.fromhex(customer_id_1c))
for row in cur.fetchall():
    print(row.OrderRef, round(row.margin_total_eur or 0, 1), round(row.margin_per_day_eur or 0, 1))
```

### Gotchas (pbi)

- **`TargetDate` БЕЗ зсуву +2000** — на відміну від `dbo._Document650._Date_Time`. Інакше фільтр періоду дасть 0 рядків.
- **`OrderRef` UPPERCASE**, `Load.id_1c` lowercase → при join до TMS Postgres обов'язково `lower(OrderRef)`.
- **Гранулярність = рейс×день** → маржа за рейс лише через `SUM(...) GROUP BY OrderRef`; `DayPart` не множити повторно.
- **~20% рядків Fact мають `OrderRef = NULL`** (дні простою тягача). `INNER JOIN` на Document650 їх відсіює; для fleet-метрик враховувати свідомо.
- **`TargetTableReal` порожня** (0 рядків) — є лише Fact і Plan.
- **Майбутні TargetDate** (forecast) → `TargetDate < today`.
- **Джерело маржі ≠ TMS:** `pbi.TargetTableFact.MarginPerDay` — це **незалежна 1С-маржа**; TMS `Load.margin_per_day_eur` рахується власним `fuel_engine`. Це **різні числа** — обирати джерело свідомо (для 1С-звітності → pbi).
- **Дублі контрагентів** у Reference123 (філії, видалені `_Marked=01`, нерезиденти) → агрегувати лише по конкретному `_IDRRef`, не по `_Description`.
- **Валюта TargetTable\***: непрямо EUR (IncomePerDay/MarginPerDay порядку сотень). Якщо потрібна 100% валютна впевненість для фінзвіту — підтвердити з власником BI.

---

## Реєстр ТЗ → паливна/EETS-картка Eurowag (PAN) + OBU — `_InfoRg27104` / `_Reference294`

Джерело колонки **«Карта»** у toll-таблицях (Eurowag/T4E). Дає **активну** паливну картку Eurowag (15-знач. PAN, BIN `789663`) за держ. номером тягача. Перевірено 11/11 машин зі зразка (2026-07-01).

### Таблиці

| Об'єкт | Роль |
|--------|------|
| **`_InfoRg27104`** | Періодичний регістр — **місток картка ↔ ТЗ** (4501 рядок) |
| **`_Reference294`** | Довідник карток/OBU (ієрархічний: групи = провайдери). Номер у `_Code`/`_Description` (3789 рядків) |
| `_InfoRg23603` | Держ. номер ТЗ (`_Fld23607`) ↔ vehicle ref (`_Fld23604RRef`) |

### `_InfoRg27104` — поля

| Поле | Тип | Зміст |
|------|-----|-------|
| `_Period` | datetime (+2000) | Період реєстрації. **MAX(_Period) = активна картка** |
| `_Fld27105RRef` | binary(16) | FK → `_Reference294` (картка або OBU) |
| `_Fld27106RRef` | binary(16) | FK → `_Reference167` (тягач/ТЗ) |
| `_Fld27141RRef` | binary(16) | FK → провайдер. Eurowag = `0xbffe92b3b86d293f11e989f6d9229850` («W.A.G. payment solution») |

### `_Reference294` — номер картки

- Eurowag fuel/EETS PAN → `_Description LIKE '789663%'` (15 цифр).
- OBU ID → `_Description LIKE '000070%'` (15 цифр).
- `_Folder=0x00` = група-провайдер, `0x01` = картка. `_ParentIDRRef` → провайдер.

### Як обрати АКТИВНУ картку (критично)

На одну машину висить **7–38** записів (старі картки різних мереж, OBU — нічого не видаляється).
- **`_Marked` НЕ юзати** — майже завжди `0x00` (не індикатор активності).
- Гіпотеза «префікс 78» **неточна**: `7825…`(WOG), `7077…`, `7921…`, `7033…`, `7824…` — інші мережі. Саме **`789663`** = Eurowag.
- **Правило:** `_Description LIKE '789663%'` → серед них `MAX(_Period)`. Провайдер-фільтр (`_Fld27141RRef=WAG`) надлишковий (дає ту саму множину — 119=119 машин), але допустимий.

### SELECT «активна картка по держ. номеру»

```sql
;WITH veh AS (
    SELECT _Fld23604RRef AS vref
    FROM dbo._InfoRg23603 WHERE RTRIM(_Fld23607) = ?      -- 'BO9202EI'
)
SELECT TOP 1 LTRIM(RTRIM(r._Description)) AS card_pan
FROM dbo._InfoRg27104 ir
JOIN dbo._Reference294 r ON ir._Fld27105RRef = r._IDRRef
JOIN veh                 ON ir._Fld27106RRef = veh.vref
WHERE LTRIM(RTRIM(r._Description)) LIKE '789663%'          -- BIN Eurowag
ORDER BY ir._Period DESC;                                 -- найпізніший = активна
```

Для OBU — те саме з `LIKE '000070%'`.

### Покриття та застереження

- **Картка: 119 машин** ≈ весь активний автопарк (~120 FLEET_WHITELIST). Ручне заповнення майже не потрібне.
- **OBU: лише 68 машин** (~57%) у 1С; частина відсутня навіть у Reference294 (напр. `000070003016630`). **OBU брати з toll4europe (T4E)**, 1С — вторинна довідка.
- `_Fld27141RRef` (провайдер) — **binary(16)**, у pyodbc `bytes.fromhex(...)`, НЕ hex-рядком (інакше 0 рядків).
- Держ. номер (`_Fld23607`) і `_Description` — з хвостовими пробілами → `RTRIM`/`LTRIM(RTRIM())`.
- Той самий PAN може мати кілька періодів → `ORDER BY _Period DESC` / `ROW_NUMBER` коректно згортає.

