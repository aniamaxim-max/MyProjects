-- select * from pbi.v_FactNormExpenses where OrderRef = '80B902B31CC3E40111F1BC0CC7E438AC'
-- select * from pbi.vb_FactNormExpenses
--
-- Різниця фактичних та нормативних витрат у розрізі замовлення,
-- основні статті розбиті по факторах.
-- Гранулярність: OrderRef x ExpensesRef x Factor. Усі суми/ціни — EUR без ПДВ.
--
--   Пальне для вантажних ТЗ (ПВ)  -> Відстань(км) / Ціна(євро) / Використане паливо(літри)
--   AD Blue                        -> Відстань(км) / Ціна(євро) / Використане AdBlue(літри)
--   Зарплата водіїв вантажних ТЗ   -> Кількість днів(од)
--   ЄСВ Офіс                       -> Кількість днів(од)
--   Мийки внутрішні                -> Кількість документів постачання(од)
--   Дороги                         -> Відстань по Європі(км) / Вартість 1 км по Європі(євро)
--   Всі інші статті                -> Сума за послугу(євро)

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_FactNormExpenses' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_FactNormExpenses
GO

CREATE VIEW pbi.vb_FactNormExpenses AS
WITH
-- Заявки з 2024 року (відсікаємо все до 2024)
orders AS (
    SELECT OrderRef FROM pbi.vb_DimOrders WHERE OrderDate >= '2024-01-01'
),
-- Планові фізичні показники (путевий лист Document684)
doc684 AS (
    SELECT _Fld19449RRef AS OrderRef,
           SUM(_Fld19457+_Fld19458+_Fld19459+_Fld19460+_Fld19461+_Fld19462) AS DistPlan,
           SUM(_Fld19466+_Fld19467+_Fld19468+_Fld34578+_Fld34579)          AS FuelLitersPlan,
           SUM(_Fld33824)                                                  AS AdBlueLitersPlan
    FROM dbo._Document684
    WHERE _Date_Time >= '4024-01-01'
    GROUP BY _Fld19449RRef
),
-- Країна маршруту: Україна лише якщо ОБИДВІ точки UA, інакше — Європа.
-- (Європа = щонайменше одна точка не Україна). Reference283 ~24k рядків
route_eu AS (
    SELECT r._IDRRef AS RouteRef,
           CASE WHEN ISNULL(dep.CountryName, N'') = N'Україна'
                 AND ISNULL(arr.CountryName, N'') = N'Україна'
                THEN 0 ELSE 1 END AS IsEurope
    FROM dbo._Reference283 r
    LEFT JOIN pbi.vb_Point dep ON dep.PointRef = r._Fld3645RRef
    LEFT JOIN pbi.vb_Point arr ON arr.PointRef = r._Fld3644RRef
),
-- Фактичний пробіг по путевих листах (тільки валідні листи) + європейська частина
rstd AS (
    SELECT t.OrderRef,
           SUM(t.DistanceFact) AS DistFact,
           SUM(CASE WHEN re.IsEurope = 1 THEN t.DistanceFact ELSE 0 END) AS DistEuroFact
    FROM pbi.vb_RouteSheetTask t
    INNER JOIN pbi.vb_RouteSheet rv ON rv.RouteSheetRef = t.RouteSheetRef
    LEFT JOIN route_eu re ON re.RouteRef = t.RouteRef
    GROUP BY t.OrderRef
),
-- Планова європейська відстань із маршрутів замовлення (VT17775._Fld17782)
roads_plan AS (
    SELECT vt._Document650_IDRRef AS OrderRef,
           SUM(CASE WHEN re.IsEurope = 1 THEN vt._Fld17782 ELSE 0 END) AS DistEuroPlan
    FROM dbo._Document650_VT17775 vt
    LEFT JOIN route_eu re ON re.RouteRef = vt._Fld17777RRef
    GROUP BY vt._Document650_IDRRef
),
-- Фактичні літри пального/AdBlue (регістр _InfoRg27144, фактичні норми)
fuel_fact AS (
    SELECT OrderRef,
           SUM(CASE WHEN FuelRef = 0x9438B52C1CA5BDB511E67F079576A5AA THEN Liters ELSE 0 END) AS FuelLitersFact,
           SUM(CASE WHEN FuelRef = 0x8FB38F26694ED7DA11E6800A888F6CE7 THEN Liters ELSE 0 END) AS AdBlueLitersFact
    FROM (
        SELECT _Fld27149_RRRef AS OrderRef, _Fld27146RRef AS FuelRef,
               SUM(_Fld27182+_Fld27183+_Fld27184+_Fld27185+_Fld27186+_Fld27187+_Fld27188
                   +_Fld27189+_Fld27190+_Fld27191+_Fld27192+_Fld27193+_Fld27194) AS Liters
        FROM dbo._InfoRg27144
        WHERE _Active = 0x01 AND _Period >= '4024-01-01'
        GROUP BY _Fld27149_RRRef, _Fld27146RRef
    ) z
    GROUP BY OrderRef
),
-- Планові суми по статтях (EUR без ПДВ) + планова к-сть документів постачання по мийках.
-- Дзеркалить pbi.vb_PlanExpenses (регістр _AccumRg26553), але без зайвого JOIN до _Document684.
plan_agg AS (
    SELECT _Fld26554_RRRef AS OrderRef,
           CASE WHEN _Fld26555RRef = 0x93E78FEF853B0AA111EB6256B4F85879
                THEN 0x983902B31CC3E40111EC7F3FD376A4F0
                ELSE _Fld26555RRef END AS ArtRef,
           SUM(_Fld26565 - _Fld26566) AS PlanSum,
           COUNT(DISTINCT CASE WHEN _Fld26555RRef IN (0x93E78FEF853B0AA111EB6256B4F85879,
                                                      0x983902B31CC3E40111EC7F3FD376A4F0)
                               THEN _RecorderRRef END) AS WashPlanDocs
    FROM dbo._AccumRg26553
    WHERE CAST(_Active AS bit) = 1 AND _Fld26565 <> 0 AND _Period >= '4024-01-01'
    GROUP BY _Fld26554_RRRef,
             CASE WHEN _Fld26555RRef = 0x93E78FEF853B0AA111EB6256B4F85879
                  THEN 0x983902B31CC3E40111EC7F3FD376A4F0
                  ELSE _Fld26555RRef END
),
-- Фактичні суми по статтях (EUR без ПДВ) + кількість документів
fact_agg AS (
    SELECT OrderRef, ExpensesRef AS ArtRef,
           SUM([Sum] - ISNULL(NDS,0)) AS FactSum,
           COUNT(*)                   AS FactCnt
    FROM pbi.vb_Expenses
    WHERE Date >= '2024-01-01'
    GROUP BY OrderRef, ExpensesRef
),
-- Одна строка на OrderRef x стаття (об'єднання план/факт)
agg AS (
    SELECT COALESCE(p.OrderRef, fa.OrderRef) AS OrderRef,
           COALESCE(p.ArtRef, fa.ArtRef)     AS ArtRef,
           p.PlanSum, p.WashPlanDocs, fa.FactSum, fa.FactCnt
    FROM plan_agg p
    FULL OUTER JOIN fact_agg fa ON fa.OrderRef = p.OrderRef AND fa.ArtRef = p.ArtRef
    WHERE COALESCE(p.OrderRef, fa.OrderRef) IN (SELECT OrderRef FROM orders)
),
-- К-сть днів: план / факт
plan_days AS (
    SELECT CONVERT(binary(16), OrderRef, 2) AS OrderRef, SUM(DayPart) AS Days
    FROM pbi.TargetTablePlan
    WHERE OrderRef IS NOT NULL AND DurationStatement = 1 AND TargetDate >= '2024-01-01'
    GROUP BY OrderRef
),
fact_days AS (
    SELECT CONVERT(binary(16), OrderRef, 2) AS OrderRef, SUM(DayPart) AS Days
    FROM pbi.TargetTableReal
    WHERE OrderRef IS NOT NULL AND DurationStatement = 1 AND TargetDate >= '2024-01-01'
    GROUP BY OrderRef
),
-- Основні статті: долучаємо фізичні показники один раз
base AS (
    SELECT m.OrderRef, m.ArtRef, m.PlanSum, m.FactSum, m.FactCnt, m.WashPlanDocs,
           d.DistPlan, d.FuelLitersPlan, d.AdBlueLitersPlan,
           rs.DistFact, rs.DistEuroFact, rp.DistEuroPlan,
           ff.FuelLitersFact, ff.AdBlueLitersFact,
           pd.Days AS PlanDays, fd.Days AS FactDays
    FROM agg m
    LEFT JOIN doc684 d ON d.OrderRef = m.OrderRef
    LEFT JOIN rstd rs ON rs.OrderRef = m.OrderRef
    LEFT JOIN roads_plan rp ON rp.OrderRef = m.OrderRef
    LEFT JOIN fuel_fact ff ON ff.OrderRef = m.OrderRef
    LEFT JOIN plan_days pd ON pd.OrderRef = m.OrderRef
    LEFT JOIN fact_days fd ON fd.OrderRef = m.OrderRef
    WHERE m.ArtRef IN (0x86F5B68AC35E4EB511E679CAA0EBCC7F,0x9647CE26E65997AA11EB774C4EFFEBB1,
                       0x86F5B68AC35E4EB511E679CAA0EBCC81,0x8DE59E02FDC0F6A111EB59912A99E1F0,
                       0x983902B31CC3E40111EC7F3FD376A4F0,0x93E78FEF853B0AA111EB62564B019359)
)
SELECT b.OrderRef, b.ArtRef AS ExpensesRef, v.Factor, v.Unit,
       ISNULL(CAST(v.[Plan] AS decimal(18,4)), 0) AS [Plan],
       ISNULL(CAST(v.[Fact] AS decimal(18,4)), 0) AS [Fact]
FROM base b
CROSS APPLY (VALUES
        -- ПАЛЬНЕ (ПВ)
        (0x86F5B68AC35E4EB511E679CAA0EBCC7F, N'Відстань',       N'км',    CAST(b.DistPlan AS decimal(18,4)),        CAST(b.DistFact AS decimal(18,4))),
        (0x86F5B68AC35E4EB511E679CAA0EBCC7F, N'Ціна',           N'євро',  CAST(b.PlanSum / NULLIF(b.FuelLitersPlan,0) AS decimal(18,4)), CAST(b.FactSum / NULLIF(b.FuelLitersFact,0) AS decimal(18,4))),
        (0x86F5B68AC35E4EB511E679CAA0EBCC7F, N'Використане паливо', N'літри', CAST(b.FuelLitersPlan AS decimal(18,4)), CAST(b.FuelLitersFact AS decimal(18,4))),
        -- AD BLUE
        (0x9647CE26E65997AA11EB774C4EFFEBB1, N'Відстань',       N'км',    CAST(b.DistPlan AS decimal(18,4)),        CAST(b.DistFact AS decimal(18,4))),
        (0x9647CE26E65997AA11EB774C4EFFEBB1, N'Ціна',           N'євро',  CAST(b.PlanSum / NULLIF(b.AdBlueLitersPlan,0) AS decimal(18,4)), CAST(b.FactSum / NULLIF(b.AdBlueLitersFact,0) AS decimal(18,4))),
        (0x9647CE26E65997AA11EB774C4EFFEBB1, N'Використане AdBlue', N'літри', CAST(b.AdBlueLitersPlan AS decimal(18,4)), CAST(b.AdBlueLitersFact AS decimal(18,4))),
        -- ЗАРПЛАТА ВОДІЇВ (ПВ) — дні
        (0x86F5B68AC35E4EB511E679CAA0EBCC81, N'Кількість днів',  N'од',    CAST(b.PlanDays AS decimal(18,4)),        CAST(b.FactDays AS decimal(18,4))),
        -- ЄСВ ОФІС — дні
        (0x8DE59E02FDC0F6A111EB59912A99E1F0, N'Кількість днів',  N'од',    CAST(b.PlanDays AS decimal(18,4)),        CAST(b.FactDays AS decimal(18,4))),
        -- МИЙКИ ВНУТРІШНІ — к-сть документів постачання
        (0x983902B31CC3E40111EC7F3FD376A4F0, N'Кількість документів постачання', N'од', CAST(b.WashPlanDocs AS decimal(18,4)), CAST(b.FactCnt AS decimal(18,4))),
        -- ДОРОГИ — відстань по Європі / вартість 1 км по Європі
        (0x93E78FEF853B0AA111EB62564B019359, N'Відстань по Європі', N'км',  CAST(b.DistEuroPlan AS decimal(18,4)),    CAST(b.DistEuroFact AS decimal(18,4))),
        (0x93E78FEF853B0AA111EB62564B019359, N'Вартість 1 км по Європі', N'євро',
            CAST(b.PlanSum / NULLIF(b.DistEuroPlan,0) AS decimal(18,4)),
            CAST(b.FactSum / NULLIF(b.DistEuroFact,0) AS decimal(18,4)))
) v(ArtRef, Factor, Unit, [Plan], [Fact])
WHERE v.ArtRef = b.ArtRef
UNION ALL
-- ВСІ ІНШІ СТАТТІ — сума за послугу
SELECT OrderRef, ArtRef, N'Сума за послугу', N'євро',
       ISNULL(CAST(PlanSum AS decimal(18,4)), 0), ISNULL(CAST(FactSum AS decimal(18,4)), 0)
FROM agg
WHERE ArtRef NOT IN (0x86F5B68AC35E4EB511E679CAA0EBCC7F,0x9647CE26E65997AA11EB774C4EFFEBB1,
                     0x86F5B68AC35E4EB511E679CAA0EBCC81,0x8DE59E02FDC0F6A111EB59912A99E1F0,
                     0x983902B31CC3E40111EC7F3FD376A4F0,0x93E78FEF853B0AA111EB62564B019359)
GO


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_FactNormExpenses' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_FactNormExpenses
GO

CREATE VIEW pbi.v_FactNormExpenses AS
SELECT
    CONVERT(VARCHAR(MAX), OrderRef, 2)    AS OrderRef,
    CONVERT(VARCHAR(MAX), ExpensesRef, 2) AS ExpensesRef,
    Factor,
    Unit,
    [Plan],
    [Fact]
FROM pbi.vb_FactNormExpenses
GO
