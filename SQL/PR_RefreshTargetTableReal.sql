-- exec work.pbi.RefreshTargetTableReal '20260101'
-- select * from pbi.TargetTableReal where TargetDate >= '20260601' order by TruckRef, TargetDate

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'RefreshTargetTableReal' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.RefreshTargetTableReal;
GO

CREATE PROCEDURE [pbi].[RefreshTargetTableReal]
    @StartDateParam DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    declare @StartDate datetime
    set @StartDate = DATEADD(MONTH, -1, CAST(@StartDateParam AS DATE))

    -- =============================================
    -- 1. AllOrders из путевых листов
    -- =============================================
    IF OBJECT_ID('tempdb..#AllOrders') IS NOT NULL DROP TABLE #AllOrders;

    CREATE TABLE #AllOrders (
        OrderRef    binary(16),
        TruckRef    binary(16),
        DriverRef   binary(16),
        StartResult DATETIME,
        EndResult   DATETIME
    );

    INSERT INTO #AllOrders
    SELECT t.OrderRef, r.TruckRef, r.DriverRef,
           MIN(t.StartFact_RShT) AS StartResult,
           MAX(t.EndFact_RShT) AS EndResult
    FROM pbi.vb_RouteSheet r
    INNER JOIN pbi.vb_RouteSheetTask t ON t.RouteSheetRef = r.RouteSheetRef
    WHERE t.OrderRef <> 0x00000000000000000000000000000000
      AND r.DateRouteEnd >= @StartDate
    GROUP BY t.OrderRef, r.TruckRef, r.DriverRef, r.RouteSheetRef;

    CREATE INDEX IX_AO_Order ON #AllOrders(OrderRef);
    CREATE INDEX IX_AO_Truck_Start_End ON #AllOrders(TruckRef, StartResult, EndResult);

    -- =============================================
    -- 2. Материализация справочников
    -- =============================================
    IF OBJECT_ID('tempdb..#Trucks') IS NOT NULL DROP TABLE #Trucks;
    SELECT TruckReff, LastTruckCompany, LastTruckCompanyReff, Description3
    INTO #Trucks
    FROM pbi.vb_DimTrucks
    WHERE Description1 = N'Тягачі' AND Description2 = N'Робочі';
    CREATE CLUSTERED INDEX IX_Trucks ON #Trucks(TruckReff);

    IF OBJECT_ID('tempdb..#DimOrders') IS NOT NULL DROP TABLE #DimOrders;
    SELECT OrderRef, TruckReff, DriverReff, ManagerReff, RouteReff, ClientReff
    INTO #DimOrders
    FROM pbi.vb_DimOrders
    WHERE OrderRef IN (SELECT OrderRef FROM #AllOrders);
    CREATE CLUSTERED INDEX IX_DimOrders_Ref ON #DimOrders(OrderRef);

    IF OBJECT_ID('tempdb..#OrderCost') IS NOT NULL DROP TABLE #OrderCost;
    SELECT OrderRef, SalesFactOrPlan
    INTO #OrderCost
    FROM pbi.vb_OrderCost
    WHERE OrderRef IN (SELECT OrderRef FROM #AllOrders);
    CREATE CLUSTERED INDEX IX_OC_Ref ON #OrderCost(OrderRef);

    IF OBJECT_ID('tempdb..#Quota') IS NOT NULL DROP TABLE #Quota;
    SELECT CompanyRef, BreakEvenPoint, QuotaUkraineLinde, QuotaEuropeLinde,
           QuotaUkraine, QuotaEurope, [Period]
    INTO #Quota
    FROM pbi.vb_Quota;
    CREATE INDEX IX_Quota_Company ON #Quota(CompanyRef);

    IF OBJECT_ID('tempdb..#PivotRoute') IS NOT NULL DROP TABLE #PivotRoute;
    SELECT PivotRouteRef, RouteType
    INTO #PivotRoute
    FROM pbi.vb_PivotRoute;
    CREATE CLUSTERED INDEX IX_PR_Ref ON #PivotRoute(PivotRouteRef);

    IF OBJECT_ID('tempdb..#TruckManagerHistory') IS NOT NULL DROP TABLE #TruckManagerHistory;
    SELECT TruckRef, ManagerRef, PeriodStart
    INTO #TruckManagerHistory
    FROM pbi.vb_TruckManagerHistory;
    CREATE INDEX IX_TMH_Truck ON #TruckManagerHistory(TruckRef);

    IF OBJECT_ID('tempdb..#DriverSalary') IS NOT NULL DROP TABLE #DriverSalary;
    SELECT Driver, [Period], DriverSalaryPerDayEUR
    INTO #DriverSalary
    FROM pbi.vb_DriverSalaryFull
    WHERE [Period] >= DATEADD(MONTH, -1, @StartDate);
    CREATE CLUSTERED INDEX IX_DS_Driver_Period ON #DriverSalary(Driver, [Period] DESC);

    IF OBJECT_ID('tempdb..#DimExpenses') IS NOT NULL DROP TABLE #DimExpenses;
    SELECT ExpRef, ExpensesType
    INTO #DimExpenses
    FROM pbi.vb_DimExpenses;
    CREATE CLUSTERED INDEX IX_DE_Ref ON #DimExpenses(ExpRef);

    -- =============================================
    -- 3. Statements
    -- =============================================
    IF OBJECT_ID('tempdb..#Statements') IS NOT NULL DROP TABLE #Statements;

    SELECT DISTINCT x.CalDate, x.TruckRef, x.StatusRef
    INTO #Statements
    FROM (
        SELECT 
            c.CalDate, s.TruckRef, s.StatusRef,
            ROW_NUMBER() OVER(PARTITION BY c.CalDate, s.TruckRef ORDER BY s.IdleDate DESC) AS RN
        FROM pbi.vb_Statement s
        INNER JOIN pbi.v_Calendar c 
            ON c.CalDate >= s.IdleStart AND c.CalDate <= s.IdleEnd AND c.CalDate >= @StartDate
    ) x
    WHERE x.RN = 1;

    CREATE INDEX IX_St_Truck_Date ON #Statements(TruckRef, CalDate);

    -- =============================================
    -- 4. TargetTable
    -- =============================================
    IF OBJECT_ID('tempdb..#TargetTable') IS NOT NULL DROP TABLE #TargetTable;

    CREATE TABLE #TargetTable (
        TruckRef          binary(16),
        TargetDate        DATETIME,
        OrderRef          binary(16),
        DriverRef         binary(16),
        StatementRef      binary(16),
        IsPaidStatement   BIT NOT NULL DEFAULT 1,
        DurationStatement BIT NOT NULL DEFAULT 1,
        DayPart           NUMERIC(10,2) NOT NULL DEFAULT 0.0,
        IncomePerDay      NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FuelExpPerDay     NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        AdBlueExpPerDay   NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RoadTaxExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        DriverSalaryExpPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        WashingExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        CustomsDutyExpPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        ParkingExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FineExpPerDay     NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        OtherExpPerDay    NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        MarginPerDay      NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        BreakEvenPointPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        QuotaPerDay       NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        MainManagerRef    binary(16),
        CurManagerRef     binary(16)
    );

    INSERT INTO #TargetTable(TruckRef, TargetDate, OrderRef, DriverRef)
    SELECT AO.TruckRef, C.CalDate, AO.OrderRef, AO.DriverRef
    FROM #AllOrders AO
    INNER JOIN pbi.v_Calendar C ON C.CalDate BETWEEN AO.StartResult AND AO.EndResult;

    INSERT INTO #TargetTable(TruckRef, TargetDate)
    SELECT DT.TruckReff, C.CalDate
    FROM pbi.v_Calendar C
    CROSS JOIN #Trucks DT
    WHERE C.CalDate >= @StartDate AND C.CalDate <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE))
      AND NOT EXISTS (
          SELECT 1 FROM #AllOrders A 
          WHERE A.TruckRef = DT.TruckReff AND C.CalDate BETWEEN A.StartResult AND A.EndResult
      );

    CREATE INDEX IX_TT_Truck_Date ON #TargetTable(TruckRef, TargetDate);

    -- =============================================
    -- 5. StatementRef
    -- =============================================
    UPDATE tt SET tt.StatementRef = s.StatusRef
    FROM #TargetTable tt
    INNER JOIN #Statements s ON s.TruckRef = tt.TruckRef AND s.CalDate = tt.TargetDate;

    -- =============================================
    -- 6. MainManagerRef
    -- =============================================
    UPDATE tt SET tt.MainManagerRef = m.ManagerRef
    FROM #TargetTable tt
    OUTER APPLY (
        SELECT TOP 1 tm.ManagerRef
        FROM #TruckManagerHistory tm
        WHERE tm.TruckRef = tt.TruckRef AND tm.PeriodStart <= tt.TargetDate
        ORDER BY tm.PeriodStart DESC
    ) m;

    -- =============================================
    -- 7. CurManagerRef
    -- =============================================
    UPDATE tt SET tt.CurManagerRef = do.ManagerReff
    FROM #TargetTable tt
    INNER JOIN #DimOrders do ON do.OrderRef = tt.OrderRef;

    -- =============================================
    -- 8. IsPaidStatement, DurationStatement
    -- =============================================
    UPDATE tt
    SET tt.IsPaidStatement = CASE WHEN ST.StatementType4 = N'Без оплати' THEN 0 ELSE 1 END,
        tt.DurationStatement = CASE WHEN ST.StatementType1 = N'Простой' THEN 0 ELSE 1 END
    FROM #TargetTable tt
    LEFT JOIN pbi.vb_StatementType ST ON ST.StatementTypeRef = tt.StatementRef;

    -- =============================================
    -- 9. DayPart
    -- =============================================
    UPDATE tt SET tt.DayPart = 1.0 / td.Cnt
    FROM #TargetTable tt
    INNER JOIN (
        SELECT TruckRef, TargetDate, COUNT(*) AS Cnt
        FROM #TargetTable GROUP BY TruckRef, TargetDate
    ) td ON td.TruckRef = tt.TruckRef AND td.TargetDate = tt.TargetDate;

    -- =============================================
    -- 10. OrderWeight
    -- =============================================
    IF OBJECT_ID('tempdb..#OrderWeight') IS NOT NULL DROP TABLE #OrderWeight;

    SELECT OrderRef, SUM(CASE WHEN DurationStatement = 1 THEN DayPart ELSE 0 END) AS TotalDayParts
    INTO #OrderWeight
    FROM #TargetTable GROUP BY OrderRef;

    -- =============================================
    -- 11. IncomePerDay
    -- =============================================
    UPDATE tt
    SET tt.IncomePerDay = 
        CASE 
            WHEN tt.DurationStatement = 0 THEN 0.0
            WHEN ow.TotalDayParts > 0 THEN ISNULL(oc.SalesFactOrPlan, 0) * tt.DayPart / ow.TotalDayParts
            ELSE 0.0 END
    FROM #TargetTable tt
    LEFT JOIN #OrderWeight ow ON ow.OrderRef = tt.OrderRef
    LEFT JOIN #OrderCost oc ON oc.OrderRef = tt.OrderRef;

    -- =============================================
    -- 12. Расходы из vb_Expenses
    -- =============================================
    IF OBJECT_ID('tempdb..#ExpensesByOrder') IS NOT NULL DROP TABLE #ExpensesByOrder;

    SELECT 
        e.OrderRef,
        SUM(CASE 
            WHEN de.ExpensesType = 'Fuel' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL)
            THEN e.Sum - CASE 
                WHEN e.ExpensesRef = 0x86F5B68AC35E4EB511E679CAA0EBCC7F 
                     AND dt.LastTruckCompany = N'Трімекс' 
                     AND (e.NDS IS NULL OR e.NDS = 0)
                THEN e.Sum * 0.2
                ELSE ISNULL(e.NDS, 0) END
            ELSE 0 END) AS FuelExpenses,
        SUM(CASE WHEN de.ExpensesType = 'AdBlue' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS AdBlueExpenses,
        SUM(CASE WHEN de.ExpensesType = 'RoadTax' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS RoadTaxExpenses,
        SUM(CASE WHEN de.ExpensesType = 'DriverSalary' AND e.DriverWork IS NOT NULL THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS DriverSalaryExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Washing' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS WashingExpenses,
        SUM(CASE WHEN de.ExpensesType = 'CustomsDuty' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS CustomsDutyExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Parking' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS ParkingExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Fine' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS FineExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Other' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork IS NOT NULL) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS OtherExpenses
    INTO #ExpensesByOrder
    FROM pbi.vb_Expenses e
    LEFT JOIN #DimExpenses de ON de.ExpRef = e.ExpensesRef
    LEFT JOIN #Trucks dt ON dt.TruckReff = e.TruckReff
    WHERE e.Date >= @StartDate
      AND e.OrderRef IN (SELECT OrderRef FROM #AllOrders)
      AND NOT (e.RegReffTable = 556 
               AND e.NomReff IN (0x85C3EE1D35F1718111E69C4735E7BE1A, 0x85C3EE1D35F1718111E69C51E454684D))
    GROUP BY e.OrderRef;

    -- =============================================
    -- 13. ExpensesPerDay по типам
    -- =============================================
    UPDATE tt
    SET 
        tt.FuelExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.FuelExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.AdBlueExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.AdBlueExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RoadTaxExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.RoadTaxExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.DriverSalaryExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.DriverSalaryExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.WashingExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.WashingExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.CustomsDutyExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.CustomsDutyExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.ParkingExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.ParkingExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FineExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.FineExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.OtherExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.OtherExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END
    FROM #TargetTable tt
    LEFT JOIN #OrderWeight ow ON ow.OrderRef = tt.OrderRef
    LEFT JOIN #ExpensesByOrder eb ON eb.OrderRef = tt.OrderRef;

    -- =============================================
    -- 14. LastDriver
    -- =============================================
    ;WITH cte_LastDriver AS (
        SELECT T.TruckRef, T.TargetDate, D.LastDriver
        FROM #TargetTable T
        CROSS APPLY (
            SELECT TOP 1 D.DriverRef AS LastDriver
            FROM #TargetTable D
            WHERE T.TruckRef = D.TruckRef 
              AND D.DriverRef IS NOT NULL AND D.DriverRef <> 0x00000000000000000000000000000000
              AND D.TargetDate < T.TargetDate
            ORDER BY D.TargetDate DESC
        ) D
        WHERE T.DriverRef IS NULL
    )
    UPDATE tt SET tt.DriverRef = c.LastDriver
    FROM #TargetTable tt
    INNER JOIN cte_LastDriver c ON c.TruckRef = tt.TruckRef AND c.TargetDate = tt.TargetDate
    WHERE tt.DriverRef IS NULL;

    -- =============================================
    -- 15. DriverSalaryExpPerDay для пустых дней
    -- =============================================
    UPDATE tt
    SET tt.DriverSalaryExpPerDay = 
        CASE WHEN tt.IsPaidStatement = 0 THEN 0.0 ELSE ISNULL(ds.DriverSalaryPerDayEUR, 0) * tt.DayPart END
    FROM #TargetTable tt
    OUTER APPLY (
        SELECT TOP 1 src.DriverSalaryPerDayEUR
        FROM #DriverSalary src
        WHERE src.Driver = tt.DriverRef AND src.[Period] <= tt.TargetDate
        ORDER BY src.[Period] DESC
    ) ds
    WHERE tt.OrderRef IS NULL;

    -- =============================================
    -- 16. MarginPerDay
    -- =============================================
    UPDATE tt
    SET tt.MarginPerDay = tt.IncomePerDay 
        - (tt.FuelExpPerDay + tt.AdBlueExpPerDay + tt.RoadTaxExpPerDay 
           + tt.DriverSalaryExpPerDay + tt.WashingExpPerDay + tt.CustomsDutyExpPerDay 
           + tt.ParkingExpPerDay + tt.FineExpPerDay + tt.OtherExpPerDay)
    FROM #TargetTable tt;

    -- =============================================
    -- 17. BreakEvenPointPerDay, QuotaPerDay
    -- =============================================
    UPDATE tt
    SET 
        tt.BreakEvenPointPerDay = ISNULL(q.BreakEvenPoint * tt.DayPart, 0),
        tt.QuotaPerDay = ISNULL((CASE
            WHEN pr.RouteType = N'Україна' AND do.ClientReff = 0xACEFD32FEC9A2DE011E680D1BDE456FD THEN q.QuotaUkraineLinde
            WHEN pr.RouteType <> N'Україна' AND do.ClientReff = 0xACEFD32FEC9A2DE011E680D1BDE456FD THEN q.QuotaEuropeLinde
            WHEN dt.Description3 = N'Україна' THEN q.QuotaUkraine
            WHEN dt.Description3 IN (N'Європа', N'EU') THEN q.QuotaEurope
            ELSE 0 END), 0) * tt.DayPart
    FROM #TargetTable tt
    LEFT JOIN #Trucks dt ON dt.TruckReff = tt.TruckRef
    LEFT JOIN #Quota q ON q.CompanyRef = dt.LastTruckCompanyReff 
        AND MONTH(q.[Period]) = MONTH(tt.TargetDate) AND YEAR(q.[Period]) = YEAR(tt.TargetDate)
    LEFT JOIN #DimOrders do ON do.OrderRef = tt.OrderRef
    LEFT JOIN #PivotRoute pr ON pr.PivotRouteRef = do.RouteReff;

    -- =============================================
    -- 18. DELETE + INSERT в pbi.TargetTableReal
    -- =============================================
    DELETE FROM pbi.TargetTableReal WHERE TargetDate >= @StartDateParam;

    INSERT INTO pbi.TargetTableReal
    SELECT
        CONVERT(VARCHAR(MAX), TruckRef, 2) AS TruckRef,
        TargetDate,
        CONVERT(VARCHAR(MAX), OrderRef, 2) AS OrderRef,
        CONVERT(VARCHAR(MAX), DriverRef, 2) AS DriverRef,
        CONVERT(VARCHAR(MAX), StatementRef, 2) AS StatementRef,
        IsPaidStatement, DurationStatement, DayPart,
        IncomePerDay, FuelExpPerDay, AdBlueExpPerDay, RoadTaxExpPerDay,
        DriverSalaryExpPerDay, WashingExpPerDay, CustomsDutyExpPerDay,
        ParkingExpPerDay, FineExpPerDay, OtherExpPerDay,
        MarginPerDay, BreakEvenPointPerDay, QuotaPerDay,
        CONVERT(VARCHAR(MAX), MainManagerRef, 2) AS MainManagerRef,
        CONVERT(VARCHAR(MAX), CurManagerRef, 2) AS CurManagerRef
    FROM #TargetTable
    WHERE TargetDate >= @StartDateParam;

    -- =============================================
    -- Cleanup
    -- =============================================
    DROP TABLE #TargetTable;
    DROP TABLE #AllOrders;
    DROP TABLE #OrderWeight;
    DROP TABLE #Statements;
    DROP TABLE #ExpensesByOrder;
    DROP TABLE #Trucks;
    DROP TABLE #DimOrders;
    DROP TABLE #OrderCost;
    DROP TABLE #Quota;
    DROP TABLE #PivotRoute;
    DROP TABLE #TruckManagerHistory;
    DROP TABLE #DriverSalary;
    DROP TABLE #DimExpenses;

END
GO