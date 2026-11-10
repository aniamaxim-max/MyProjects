-- Планові дні по заявках: повний календарний інтервал FullStartDate..FullEndDate.
-- Логіка повторює pbi.GetPlanDaysBinary (сама процедура не змінюється).
-- PlanDays = кількість днів включно; NULL / End < Start -> 0.

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_GetPlanDays' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_GetPlanDays
GO

CREATE VIEW pbi.vb_GetPlanDays AS
WITH
-- Активні заявки з 2024 року
orders AS (
    SELECT OrderRef, [Order], StartPlan, EndPlan, Active, OrderDate
    FROM pbi.vb_DimOrders
    WHERE OrderDate >= '2024-01-01' AND Active = 1
),
-- Перший непорожній маршрут заявки
min_line AS (
    SELECT D.OrderRef, MIN(DR.Line) AS MinLineNonEmpty
    FROM orders D
    INNER JOIN pbi.vb_DimOrderRoute DR ON DR.OrderRef = D.OrderRef
    WHERE DR.EmptyRoute = 0
    GROUP BY D.OrderRef
),
-- Дні порожніх маршрутів до/після основного
route_days AS (
    SELECT r.OrderRef,
           SUM(CASE WHEN r.EmptyRoute = 1
                     AND (m.MinLineNonEmpty IS NULL OR r.Line < m.MinLineNonEmpty)
                    THEN dr.NumOfDays ELSE 0 END) AS NumOfDaysBefore,
           SUM(CASE WHEN r.EmptyRoute = 1
                     AND m.MinLineNonEmpty IS NOT NULL AND r.Line > m.MinLineNonEmpty
                    THEN dr.NumOfDays ELSE 0 END) AS NumOfDaysAfter
    FROM pbi.vb_DimOrderRoute r
    LEFT JOIN min_line m ON m.OrderRef = r.OrderRef
    LEFT JOIN pbi.vb_DimRoute dr ON dr.RouteRef = r.SubRuoteRef
    WHERE r.OrderRef IN (SELECT OrderRef FROM orders)
    GROUP BY r.OrderRef
),
-- Повні дати початку/закінчення з урахуванням порожніх маршрутів
full_dates AS (
    SELECT DO.OrderRef, DO.[Order],
           DO.StartPlan AS StartDate,
           DO.EndPlan AS EndDate,
           RD.NumOfDaysBefore AS EmptyBefore,
           RD.NumOfDaysAfter AS EmptyAfter,
           DATEADD(
               DAY,
               -CASE
                   WHEN FLOOR(ISNULL(RD.NumOfDaysBefore, 0)) < 0 THEN 0
                   ELSE FLOOR(ISNULL(RD.NumOfDaysBefore, 0))
                END,
               CAST(DO.StartPlan AS date)
           ) AS FullStartDate,
           DATEADD(
               DAY,
               CASE
                   WHEN FLOOR(ISNULL(RD.NumOfDaysAfter, 0)) < 0 THEN 0
                   ELSE FLOOR(ISNULL(RD.NumOfDaysAfter, 0))
                END,
               CAST(DO.EndPlan AS date)
           ) AS FullEndDate
    FROM orders DO
    LEFT JOIN route_days RD ON RD.OrderRef = DO.OrderRef
)
SELECT OrderRef, [Order], StartDate, EndDate, EmptyBefore, EmptyAfter,
       FullStartDate, FullEndDate,
       CASE WHEN FullStartDate IS NULL OR FullEndDate IS NULL OR FullEndDate < FullStartDate
            THEN 0
            ELSE DATEDIFF(DAY, FullStartDate, FullEndDate) + 1
       END AS PlanDays
FROM full_dates
GO
