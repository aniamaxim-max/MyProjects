-- exec work.pbi.GetFactDaysBinary '20260101' exec work.pbi.GetFactDays '20260101'



IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetFactDaysBinary' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.GetFactDaysBinary;
GO

CREATE PROCEDURE [pbi].[GetFactDaysBinary]
    @StartDateParam DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;

--declare @StartDateParam datetime
--set @StartDateParam = '20260101'

declare @StartDate datetime
set @StartDate = CAST(@StartDateParam AS DATE)



IF OBJECT_ID('tempdb..#Orders') IS NOT NULL 
	DROP TABLE #Orders;

CREATE TABLE #Orders (
	OrderRef binary(16), 
	[Order] varchar(12), 
	StartFact datetime, 
	EndFact datetime, 
	StartPlan datetime, 
	EndPlan datetime, 
	OrderDate datetime, 
	Active bit
)

INSERT INTO #Orders
SELECT OrderRef, [Order], StartFact, EndFact, StartPlan, EndPlan, OrderDate, Active
FROM pbi.vb_DimOrders
WHERE OrderDateRaw >= DATEADD(YEAR, 2000, @StartDate) AND Active = 1;

CREATE INDEX IX_Orders_OrderRef ON #Orders(OrderRef);



IF OBJECT_ID('tempdb..#MinLineNonEmpty') IS NOT NULL
	DROP TABLE #MinLineNonEmpty;

CREATE TABLE #MinLineNonEmpty (
	OrderRef binary(16) not null,
	MinLineNonEmpty int,
	Primary Key (OrderRef)
)

INSERT INTO #MinLineNonEmpty
SELECT 
    D.OrderRef,
    MIN(Line) AS MinLineNonEmpty
FROM #Orders D
INNER JOIN pbi.vb_DimOrderRoute DR ON DR.OrderRef = D.OrderRef
WHERE EmptyRoute = 0
GROUP BY D.OrderRef;

IF OBJECT_ID('tempdb..#RouteSheetTask') IS NOT NULL
	DROP TABLE #RouteSheetTask;

CREATE TABLE #RouteSheetTask (
	OrderRef binary(16) not null,
	StartFact_RShT datetime,
    EndFact_RShT datetime,
    RouteSheetRef binary(16)
)

INSERT INTO #RouteSheetTask
SELECT OrderRef, StartFact_RShT, EndFact_RShT, RouteSheetRef
FROM pbi.vb_RouteSheetTask
WHERE OrderRef IN (select OrderRef from #Orders)
	AND RouteSheetRef in (select RouteSheetRef from pbi.vb_RouteSheet)

;WITH cte_RouteDays AS (
    SELECT 
        r.OrderRef,
        SUM(
            ISNULL(CASE 
                        WHEN r.EmptyRoute = 1 
                             AND (m.MinLineNonEmpty IS NULL OR r.Line < m.MinLineNonEmpty)
                        THEN dr.NumOfDays
                        ELSE 0
                    END, 0)) AS NumOfDaysBefore,
        SUM(
            ISNULL(CASE 
                        WHEN r.EmptyRoute = 1 
                             AND m.MinLineNonEmpty IS NOT NULL AND r.Line > m.MinLineNonEmpty
                        THEN dr.NumOfDays
                        ELSE 0
                    END, 0)) AS NumOfDaysAfter
    FROM pbi.vb_DimOrderRoute r
    LEFT JOIN #MinLineNonEmpty m
        ON m.OrderRef = r.OrderRef
    LEFT JOIN pbi.vb_DimRoute dr
        ON dr.RouteRef = r.SubRuoteRef
	Where r.OrderRef in (select OrderRef from #Orders)
    GROUP BY r.OrderRef)
, cte_FactDays AS (
    SELECT 
        OrderRef,
        MIN(StartFact_RShT) AS MinStartFact
    FROM #RouteSheetTask
    WHERE StartFact_RShT IS NOT NULL      
    GROUP BY OrderRef
)
, cte_FactEnd AS (
    SELECT 
        t.OrderRef,
        -- максимальна дата завершення
        MAX(t.EndFact_RShT) AS MaxEndFact,
        -- скільки всього рядків
        COUNT(*) AS TotalRows,
        -- скільки рядків з датою
        SUM(CASE WHEN t.EndFact_RShT IS NOT NULL THEN 1 ELSE 0 END) AS FilledRows,
		-- чи є хоча б один завершений сегмент
        MAX(CASE WHEN rs.RouteIsInProgress = 0 THEN 1 ELSE 0 END) AS HasCompletedSegment
    FROM #RouteSheetTask t
    LEFT JOIN pbi.vb_RouteSheet rs
        ON rs.RouteSheetRef = t.RouteSheetRef
    GROUP BY t.OrderRef
)
/*, cte_RouteSheetComplete AS (
    SELECT 
        OrderRef,        
		-- чи є хоча б один завершений сегмент
        MAX(CASE WHEN rs.RouteIsInProgress = 0 THEN 1 ELSE 0 END) AS HasCompletedSegment
    FROM pbi.vb_RouteSheet rs
    INNER JOIN #RouteSheetTask t
        ON rs.RouteSheetRef = t.RouteSheetRef
    GROUP BY t.OrderRef
)*/
SELECT 
    DO.OrderRef,
	DO.[Order],
    DO.StartFact AS StartDate,
    DO.EndFact AS EndDate,
    RD.NumOfDaysBefore AS EmptyBefore,
	RD.NumOfDaysAfter AS EmptyAfter,
	COALESCE(FD.MinStartFact, 
        DATEADD(
            DAY,
            -CASE 
                WHEN FLOOR(ISNULL(RD.NumOfDaysBefore, 0)) < 0 THEN 0
                ELSE FLOOR(ISNULL(RD.NumOfDaysBefore, 0))
             END,
            CAST(DO.StartPlan AS date)
        )
    ) AS FullStartDate,
    CASE 
        WHEN FE.TotalRows > 0
             AND FE.TotalRows = FE.FilledRows
             AND FE.HasCompletedSegment = 1
        THEN FE.MaxEndFact
	    WHEN DO.EndFact IS NOT NULL THEN DO.EndFact

        ELSE DATEADD(
            DAY,
            CASE 
                WHEN FLOOR(ISNULL(RD.NumOfDaysAfter, 0)) < 0 THEN 0
                ELSE FLOOR(ISNULL(RD.NumOfDaysAfter, 0))
            END,
            CAST(DO.EndPlan AS date)
        )
    END AS FullEndDate

FROM #Orders DO
    LEFT JOIN cte_RouteDays RD    ON RD.OrderRef = DO.OrderRef
    LEFT JOIN cte_FactDays FD    ON FD.OrderRef = DO.OrderRef
    LEFT JOIN cte_FactEnd FE    ON FE.OrderRef = DO.OrderRef

--ORDER BY  DO.[Order]


DROP TABLE #MinLineNonEmpty;
DROP TABLE #RouteSheetTask;
DROP TABLE #Orders;

END
GO


