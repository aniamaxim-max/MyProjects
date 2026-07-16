DECLARE @StartDate DATE = '2026-06-01';
DECLARE @EndDate DATE = '2026-06-30';

WITH
Tractors AS (
    SELECT TruckReff, LegalNum
    FROM pbi.v_DimTrucks
    WHERE Active = 1
),
JuneDays AS (
    SELECT c.CalDate
    FROM pbi.v_Calendar c
    WHERE c.CalDate >= @StartDate
        AND c.CalDate <= @EndDate
),
TruckDays AS (
    SELECT t.TruckReff, t.LegalNum, d.CalDate
    FROM Tractors t
    CROSS JOIN JuneDays d
),
RSOrders AS (
    SELECT DISTINCT
        rst.RouteSheetRef,
        rst.OrderRef,
        o.[Order] AS OrderNumber
    FROM pbi.v_RouteSheetTask rst
    LEFT JOIN pbi.v_DimOrders o
        ON rst.OrderRef = o.OrderRef
        AND o.Active = 1
)
SELECT
    td.LegalNum AS [Автомобиль],
    COALESCE(dp.Name, de.Employee) AS [Водитель],
    tsk.OrderNumber AS [Заказ],
    td.CalDate AS [Дата]
FROM TruckDays td
OUTER APPLY (
    SELECT TOP 1 rs.DriverRef, rs.RouteSheetRef
    FROM pbi.v_RouteSheet rs
    WHERE rs.TruckRef = td.TruckReff
        AND TRY_CAST(rs.DateRouteStart AS DATE) <= td.CalDate
        AND TRY_CAST(rs.DateRouteEnd AS DATE) >= td.CalDate
    ORDER BY TRY_CAST(rs.DateRouteStart AS DATE)
) active
OUTER APPLY (
    SELECT TOP 1 rso.OrderNumber
    FROM RSOrders rso
    WHERE rso.RouteSheetRef = active.RouteSheetRef
) tsk
OUTER APPLY (
    SELECT TOP 1 fallback.DriverRef
    FROM pbi.v_RouteSheet fallback
    WHERE fallback.TruckRef = td.TruckReff
        AND TRY_CAST(fallback.DateRouteEnd AS DATE) < td.CalDate
        AND active.DriverRef IS NULL
    ORDER BY fallback.DateRouteEnd DESC
) fallback
OUTER APPLY (
    SELECT TOP 1 p.Name
    FROM pbi.v_DimPeople p
    WHERE p.PeopleRef = COALESCE(active.DriverRef, fallback.DriverRef)
) dp
OUTER APPLY (
    SELECT TOP 1 e.Employee
    FROM pbi.v_DimEmployee e
    WHERE e.EmployeeReff = COALESCE(active.DriverRef, fallback.DriverRef)
        AND dp.Name IS NULL
) de
ORDER BY td.LegalNum, td.CalDate;
