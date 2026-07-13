USE [work]
GO

/****** Object:  StoredProcedure [pbi].[GetPlanDays]    Script Date: 18.05.2026 15:39:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [pbi].[GetPlanDays]
    @StartDateParam DATETIME
AS
BEGIN
    SET NOCOUNT ON;

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
	AND D.OrderDate >= @StartDate
	AND D.Active = 1
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
    FROM pbi.v_DimOrderRoute r
    LEft JOIN #MinLineNonEmpty m
        ON m.OrderRef = r.OrderRef
    LEFT JOIN pbi.v_DimRoute dr
        ON dr.RouteRef = r.SubRuoteRef
	Where r.OrderRef in (select OrderRef from pbi.v_DimOrders where OrderDate >=  @StartDate AND Active = 1)
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
FROM pbi.v_DimOrders DO
left JOIN RouteDays RD
    ON RD.OrderRef = DO.OrderRef
WHERE DO.OrderDate >=  @StartDate
	AND DO.Active = 1
--ORDER BY  DO.[Order]

DROP TABLE #MinLineNonEmpty
END
GO


