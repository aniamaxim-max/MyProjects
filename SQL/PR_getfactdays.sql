USE [work]
GO

/****** Object:  StoredProcedure [pbi].[GetFactDays]    Script Date: 18.05.2026 15:38:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [pbi].[GetFactDays]
    @StartDateParam DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;

--declare @StartDateParam datetime
--set @StartDateParam = '20260101'

declare @StartDate datetime
set @StartDate = CAST(@StartDateParam AS DATE)

IF OBJECT_ID('tempdb..#MinLineNonEmpty') IS NOT NULL
	DROP TABLE #MinLineNonEmpty;

CREATE TABLE #MinLineNonEmpty (
	OrderRef varchar(255) not null,
	MinLineNonEmpty int,
	Primary Key (OrderRef)
)

INSERT INTO #MinLineNonEmpty
SELECT 
    D.OrderRef,
    MIN(Line) AS MinLineNonEmpty
FROM pbi.v_DimOrders D
INNER JOIN pbi.v_DimOrderRoute DR ON DR.OrderRef = D.OrderRef
WHERE EmptyRoute = 0
	AND D.OrderDate >=  @StartDate
	AND D.Active = 1
GROUP BY D.OrderRef;

IF OBJECT_ID('tempdb..#RouteSheetTask') IS NOT NULL
	DROP TABLE #RouteSheetTask;

CREATE TABLE #RouteSheetTask (
	OrderRef varchar(255) not null,
	StartFact_RShT datetime,
    EndFact_RShT datetime,
    RouteSheetRef varchar(255)
)

INSERT INTO #RouteSheetTask
SELECT OrderRef, StartFact_RShT, EndFact_RShT, RouteSheetRef
FROM pbi.v_RouteSheetTask
WHERE OrderRef IN (select OrderRef from pbi.v_DimOrders where OrderDate >= @StartDate AND Active = 1)
	AND RouteSheetRef in (select RouteSheetRef from pbi.v_RouteSheet)

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
    FROM pbi.v_DimOrderRoute r
    LEFT JOIN #MinLineNonEmpty m
        ON m.OrderRef = r.OrderRef
    LEFT JOIN pbi.v_DimRoute dr
        ON dr.RouteRef = r.SubRuoteRef
	Where r.OrderRef in (select OrderRef from pbi.v_DimOrders where OrderDate >= @StartDate AND Active = 1)
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
    LEFT JOIN pbi.v_RouteSheet rs
        ON rs.RouteSheetRef = t.RouteSheetRef
    GROUP BY t.OrderRef
)
, cte_RouteSheetComplete AS (
    SELECT 
        OrderRef,        
		-- чи є хоча б один завершений сегмент
        MAX(CASE WHEN rs.RouteIsInProgress = 0 THEN 1 ELSE 0 END) AS HasCompletedSegment
    FROM pbi.v_RouteSheet rs
    INNER JOIN #RouteSheetTask t
        ON rs.RouteSheetRef = t.RouteSheetRef
    GROUP BY t.OrderRef
)
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

FROM pbi.v_DimOrders DO
    LEFT JOIN cte_RouteDays RD    ON RD.OrderRef = DO.OrderRef
    LEFT JOIN cte_FactDays FD    ON FD.OrderRef = DO.OrderRef
    LEFT JOIN cte_FactEnd FE    ON FE.OrderRef = DO.OrderRef
WHERE DO.OrderDate >=  @StartDate AND DO.Active = 1
--ORDER BY  DO.[Order]


DROP TABLE #MinLineNonEmpty;
DROP TABLE #RouteSheetTask;

END
GO


