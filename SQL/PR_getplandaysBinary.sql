-- exec work.pbi.GetPlanDaysBinary '20260101' exec work.pbi.GetPlanDays '20260101'



IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetPlanDaysBinary' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.GetPlanDaysBinary;
GO

CREATE PROCEDURE [pbi].[GetPlanDaysBinary]
    @StartDateParam DATETIME
AS
BEGIN
    SET NOCOUNT ON;

--declare @StartDateParam datetime
--set @StartDateParam = '20260101'

declare @StartDate datetime
set @StartDate = CAST(@StartDateParam AS DATE)

IF OBJECT_ID('tempdb..#Orders') IS NOT NULL 
	DROP TABLE #Orders;

CREATE TABLE #Orders (
	OrderRef binary(16), 
	[Order] varchar(12), 
	StartPlan datetime, 
	EndPlan datetime, 
	Active bit,
	OrderDate datetime	
)

INSERT INTO #Orders
SELECT OrderRef, [Order], StartPlan, EndPlan, Active, OrderDate
FROM pbi.vb_DimOrders
WHERE OrderDateRaw >= DATEADD(YEAR, 2000, @StartDate) AND Active = 1

CREATE INDEX IX_Orders_OrderRef ON #Orders(OrderRef);

IF OBJECT_ID('tempdb..#MinLineNonEmpty') IS NOT NULL 
		DROP TABLE #MinLineNonEmpty;

CREATE TABLE #MinLineNonEmpty (
	OrderRef		binary(16) not null,
	MinLineNonEmpty int,
	Primary Key		(OrderRef)
)

INSERT INTO #MinLineNonEmpty
SELECT 
    D.OrderRef,
    MIN(Line) AS MinLineNonEmpty
FROM #Orders D
INNER JOIN pbi.vb_DimOrderRoute DR ON DR.OrderRef = D.OrderRef
WHERE EmptyRoute = 0
--	AND D.OrderDate >= @StartDate	AND D.Active = 1
GROUP BY D.OrderRef;

;WITH RouteDays AS (
    SELECT 
        r.OrderRef,
        SUM(
            CASE 
                WHEN r.EmptyRoute = 1 
                     AND (m.MinLineNonEmpty IS NULL OR r.Line < m.MinLineNonEmpty)
                THEN dr.NumOfDays
                ELSE 0
            END) AS NumOfDaysBefore,
        SUM(
            CASE 
                WHEN r.EmptyRoute = 1 
                     AND m.MinLineNonEmpty IS NOT NULL AND r.Line > m.MinLineNonEmpty
                THEN dr.NumOfDays
                ELSE 0
            END) AS NumOfDaysAfter
    FROM pbi.vb_DimOrderRoute r
    LEft JOIN #MinLineNonEmpty m
        ON m.OrderRef = r.OrderRef
    LEFT JOIN pbi.vb_DimRoute dr
        ON dr.RouteRef = r.SubRuoteRef
	Where r.OrderRef in (select OrderRef from #Orders)
    GROUP BY r.OrderRef)
SELECT 
    DO.OrderRef,
	DO.[Order],
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
FROM #Orders DO
left JOIN RouteDays RD ON RD.OrderRef = DO.OrderRef
--WHERE DO.OrderDate >=  @StartDate	AND DO.Active = 1
--ORDER BY  DO.[Order]

DROP TABLE #MinLineNonEmpty
DROP TABLE #Orders
END
GO


