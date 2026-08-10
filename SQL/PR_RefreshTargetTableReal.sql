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

    -- Обновляем FactSplit (сама по себе нигде не вызывается)
    EXEC work.pbi.RefreshTargetTableFactSplit @StartDateParam

    -- =============================================
    -- 1. AllOrders из путевых листов
    --    Заявка подходит, если среди ВСЕХ её ПЛ (любая дата)
    --    есть хотя бы один закрытый без флага:
    --    DateRouteEnd IS NOT NULL AND RouteIsInProgress = 0
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
      AND t.OrderRef IN (
          SELECT t2.OrderRef
          FROM pbi.vb_RouteSheet r2
          INNER JOIN pbi.vb_RouteSheetTask t2 ON t2.RouteSheetRef = r2.RouteSheetRef
          WHERE t2.OrderRef <> 0x00000000000000000000000000000000
          GROUP BY t2.OrderRef
          HAVING MAX(CASE WHEN r2.DateRouteEnd IS NOT NULL AND r2.RouteIsInProgress = 0 THEN 1 ELSE 0 END) = 1
      )
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
    -- 4. FactRows / FactSplit (источники из TargetTableFact)
    -- =============================================
    IF OBJECT_ID('tempdb..#FactRows') IS NOT NULL DROP TABLE #FactRows;

    SELECT
        CONVERT(binary(16), f.TruckRef, 2) AS TruckRef,
        f.TargetDate,
        CONVERT(binary(16), f.OrderRef, 2) AS OrderRef,
        CONVERT(binary(16), f.DriverRef, 2) AS DriverRef,
        CONVERT(binary(16), f.StatementRef, 2) AS StatementRef,
        f.DayPart,
        f.IncomePerDay,
        f.DriverSalaryPerDay,
        ROW_NUMBER() OVER(PARTITION BY CONVERT(binary(16), f.TruckRef, 2), f.TargetDate ORDER BY f.DayPart DESC, f.OrderRef) AS RN
    INTO #FactRows
    FROM pbi.TargetTableFact f
    WHERE f.TargetDate >= @StartDate;

    CREATE INDEX IX_FR_Truck_Date ON #FactRows(TruckRef, TargetDate) INCLUDE(OrderRef, DriverRef, StatementRef, DayPart, IncomePerDay, DriverSalaryPerDay, RN);
    CREATE INDEX IX_FR_Order ON #FactRows(OrderRef, TargetDate);

    IF OBJECT_ID('tempdb..#FactSplit') IS NOT NULL DROP TABLE #FactSplit;

    SELECT
        CONVERT(binary(16), s.OrderRef, 2) AS OrderRef,
        s.FuelExpTotal, s.AdBlueExpTotal, s.RoadTaxExpTotal,
        s.WashingExpTotal, s.CustomsDutyExpTotal, s.ParkingExpTotal,
        s.FineExpTotal, s.OtherExpTotal
    INTO #FactSplit
    FROM pbi.TargetTableFactSplit s
    WHERE s.OrderRef IS NOT NULL;

    CREATE CLUSTERED INDEX IX_FS_Order ON #FactSplit(OrderRef);

    -- =============================================
    -- 5. TargetTable
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
        RealFuelExpPerDay     NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealAdBlueExpPerDay   NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealRoadTaxExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealDriverSalaryExpPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealWashingExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealCustomsDutyExpPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealParkingExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealFineExpPerDay     NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RealOtherExpPerDay    NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactFuelExpPerDay     NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactAdBlueExpPerDay   NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactRoadTaxExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactWashingExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactCustomsDutyExpPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactParkingExpPerDay  NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactFineExpPerDay     NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactOtherExpPerDay    NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FactDriverSalaryPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FuelExpPerDay       NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FuelExpPerDaySource VARCHAR(1) NULL,
        AdBlueExpPerDay     NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        AdBlueExpPerDaySource VARCHAR(1) NULL,
        RoadTaxExpPerDay    NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        RoadTaxExpPerDaySource VARCHAR(1) NULL,
        DriverSalaryExpPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        DriverSalaryExpPerDaySource VARCHAR(1) NULL,
        WashingExpPerDay    NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        WashingExpPerDaySource VARCHAR(1) NULL,
        CustomsDutyExpPerDay NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        CustomsDutyExpPerDaySource VARCHAR(1) NULL,
        ParkingExpPerDay    NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        ParkingExpPerDaySource VARCHAR(1) NULL,
        FineExpPerDay       NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        FineExpPerDaySource VARCHAR(1) NULL,
        OtherExpPerDay      NUMERIC(10,4) NOT NULL DEFAULT 0.0,
        OtherExpPerDaySource VARCHAR(1) NULL,
        ExpensesPerDay      NUMERIC(10,4) NOT NULL DEFAULT 0.0,
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
    -- 6. StatementRef
    -- =============================================
    UPDATE tt SET tt.StatementRef = s.StatusRef
    FROM #TargetTable tt
    INNER JOIN #Statements s ON s.TruckRef = tt.TruckRef AND s.CalDate = tt.TargetDate;

    -- =============================================
    -- 7. MainManagerRef
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
    -- 8. CurManagerRef
    -- =============================================
    UPDATE tt SET tt.CurManagerRef = do.ManagerReff
    FROM #TargetTable tt
    INNER JOIN #DimOrders do ON do.OrderRef = tt.OrderRef;

    -- =============================================
    -- 9. IsPaidStatement, DurationStatement (до DayPart/#OrderWeight)
    -- =============================================
    UPDATE tt
    SET tt.IsPaidStatement = CASE WHEN ST.StatementType4 = N'Без оплати' THEN 0 ELSE 1 END,
        tt.DurationStatement = CASE WHEN ST.StatementType1 = N'Простой' THEN 0 ELSE 1 END
    FROM #TargetTable tt
    LEFT JOIN pbi.vb_StatementType ST ON ST.StatementTypeRef = tt.StatementRef;

    -- =============================================
    -- 10. DayPart
    -- =============================================
    UPDATE tt SET tt.DayPart = 1.0 / td.Cnt
    FROM #TargetTable tt
    INNER JOIN (
        SELECT TruckRef, TargetDate, COUNT(*) AS Cnt
        FROM #TargetTable GROUP BY TruckRef, TargetDate
    ) td ON td.TruckRef = tt.TruckRef AND td.TargetDate = tt.TargetDate;

    -- =============================================
    -- 11. OrderWeight (по реальным заказам, ДО backfill)
    -- =============================================
    IF OBJECT_ID('tempdb..#OrderWeight') IS NOT NULL DROP TABLE #OrderWeight;

    SELECT OrderRef, SUM(CASE WHEN DurationStatement = 1 THEN DayPart ELSE 0 END) AS TotalDayParts
    INTO #OrderWeight
    FROM #TargetTable GROUP BY OrderRef;

    -- =============================================
    -- 12. IncomePerDay (реальный доход)
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
    -- 12. Реальные расходы из vb_Expenses
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
    -- 13. Реальные расходы на день
    -- =============================================
    UPDATE tt
    SET 
        tt.RealFuelExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.FuelExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealAdBlueExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.AdBlueExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealRoadTaxExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.RoadTaxExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealDriverSalaryExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.DriverSalaryExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealWashingExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.WashingExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealCustomsDutyExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.CustomsDutyExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealParkingExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.ParkingExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealFineExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.FineExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.RealOtherExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(eb.OtherExpenses, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END
    FROM #TargetTable tt
    LEFT JOIN #OrderWeight ow ON ow.OrderRef = tt.OrderRef
    LEFT JOIN #ExpensesByOrder eb ON eb.OrderRef = tt.OrderRef;

    -- =============================================
    -- 14. Backfill из TargetTableFact
    --     Для строк без заказа (OrderRef IS NULL):
    --     копируем OrderRef, DriverRef, StatementRef (если NULL),
    --     DayPart, IncomePerDay.
    --     Берем ТОЛЬКО заказы, которых нет в Real (#AllOrders) —
    --     если заказ уже встречался в Real, его в пустые дни не добавляем.
    -- =============================================
    UPDATE tt
    SET 
        tt.OrderRef = fb.OrderRef,
        tt.DriverRef = fb.DriverRef,
        tt.StatementRef = CASE WHEN tt.StatementRef IS NULL THEN fb.StatementRef ELSE tt.StatementRef END,
        tt.DayPart = fb.DayPart,
        tt.IncomePerDay = fb.IncomePerDay
    FROM #TargetTable tt
    INNER JOIN #FactRows fb 
        ON fb.TruckRef = tt.TruckRef AND fb.TargetDate = tt.TargetDate AND fb.RN = 1
    WHERE tt.OrderRef IS NULL
      AND fb.OrderRef IS NOT NULL
      AND fb.OrderRef NOT IN (SELECT OrderRef FROM #AllOrders);

    -- =============================================
    -- 15. IsPaidStatement, DurationStatement (после backfill)
    -- =============================================
    UPDATE tt
    SET tt.IsPaidStatement = CASE WHEN ST.StatementType4 = N'Без оплати' THEN 0 ELSE 1 END,
        tt.DurationStatement = CASE WHEN ST.StatementType1 = N'Простой' THEN 0 ELSE 1 END
    FROM #TargetTable tt
    LEFT JOIN pbi.vb_StatementType ST ON ST.StatementTypeRef = tt.StatementRef;

    -- =============================================
    -- 16. LastDriver (для истинно пустых дней)
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
    -- 17. RealDriverSalaryExpPerDay для истинно пустых дней
    -- =============================================
    UPDATE tt
    SET tt.RealDriverSalaryExpPerDay = 
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
    -- 18. FactDriverSalaryPerDay (для ВСЕХ строк)
    --     По заказу, если он есть; иначе по машине+дате
    -- =============================================
    UPDATE tt
    SET tt.FactDriverSalaryPerDay = ISNULL(fr.DriverSalaryPerDay, 0)
    FROM #TargetTable tt
    OUTER APPLY (
        SELECT TOP 1 f.DriverSalaryPerDay
        FROM #FactRows f
        WHERE f.TargetDate = tt.TargetDate
          AND (f.OrderRef = tt.OrderRef OR (tt.OrderRef IS NULL AND f.TruckRef = tt.TruckRef))
        ORDER BY CASE WHEN f.OrderRef = tt.OrderRef THEN 0 ELSE 1 END, f.RN
    ) fr;

    -- =============================================
    -- 19. FactOrderWeight (после backfill)
    -- =============================================
    IF OBJECT_ID('tempdb..#FactOrderWeight') IS NOT NULL DROP TABLE #FactOrderWeight;

    SELECT OrderRef, SUM(CASE WHEN DurationStatement = 1 THEN DayPart ELSE 0 END) AS TotalDayParts
    INTO #FactOrderWeight
    FROM #TargetTable GROUP BY OrderRef;

    -- =============================================
    -- 20. Fact-расходы (8 колонок из FactSplit)
    -- =============================================
    UPDATE tt
    SET 
        tt.FactFuelExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.FuelExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FactAdBlueExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.AdBlueExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FactRoadTaxExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.RoadTaxExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FactWashingExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.WashingExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FactCustomsDutyExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.CustomsDutyExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FactParkingExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.ParkingExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FactFineExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.FineExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END,
        tt.FactOtherExpPerDay = CASE WHEN tt.DurationStatement = 0 THEN 0.0 WHEN ow.TotalDayParts > 0 THEN ISNULL(fs.OtherExpTotal, 0) * tt.DayPart / ow.TotalDayParts ELSE 0.0 END
    FROM #TargetTable tt
    LEFT JOIN #FactOrderWeight ow ON ow.OrderRef = tt.OrderRef
    LEFT JOIN #FactSplit fs ON fs.OrderRef = tt.OrderRef;

    -- =============================================
    -- 21. MarginPerDay — считается ПОСЛЕ отбора (шаг 24)
    -- =============================================
    -- (MarginPerDay = IncomePerDay - сумма отобранных расходов)

    -- =============================================
    -- 22. BreakEvenPointPerDay, QuotaPerDay
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
    -- 23. Отбор Real/Fact по каждой паре расходов
    --     Группа 1 (Fuel, AdBlue, DriverSalary):
    --       real > 0 -> real, иначе fact
    --     Группа 2 (остальные):
    --       EndFact < GETDATE()-1 месяц -> real
    --       иначе max(real, fact), при равенстве -> real
    -- =============================================
    IF OBJECT_ID('tempdb..#OrderEndFact') IS NOT NULL DROP TABLE #OrderEndFact;

    SELECT OrderRef, EndFact
    INTO #OrderEndFact
    FROM pbi.vb_DimOrders
    WHERE OrderRef IN (SELECT OrderRef FROM #TargetTable WHERE OrderRef IS NOT NULL);

    CREATE CLUSTERED INDEX IX_OEF_Order ON #OrderEndFact(OrderRef);

    -- Группа 1: Fuel, AdBlue, DriverSalary
    -- AdBlue: если Fuel имеет источник 'R', то и AdBlue берём real (даже 0) с источником 'R'
    UPDATE tt
    SET 
        tt.FuelExpPerDay = CASE WHEN tt.RealFuelExpPerDay > 0 THEN tt.RealFuelExpPerDay ELSE tt.FactFuelExpPerDay END,
        tt.FuelExpPerDaySource = CASE WHEN tt.RealFuelExpPerDay > 0 THEN 'R' ELSE 'F' END,
        tt.AdBlueExpPerDay = CASE
            WHEN tt.RealFuelExpPerDay > 0 THEN tt.RealAdBlueExpPerDay
            WHEN tt.RealAdBlueExpPerDay > 0 THEN tt.RealAdBlueExpPerDay
            ELSE tt.FactAdBlueExpPerDay END,
        tt.AdBlueExpPerDaySource = CASE
            WHEN tt.RealFuelExpPerDay > 0 THEN 'R'
            WHEN tt.RealAdBlueExpPerDay > 0 THEN 'R'
            ELSE 'F' END,
        tt.DriverSalaryExpPerDay = CASE WHEN tt.RealDriverSalaryExpPerDay > 0 THEN tt.RealDriverSalaryExpPerDay ELSE tt.FactDriverSalaryPerDay END,
        tt.DriverSalaryExpPerDaySource = CASE WHEN tt.RealDriverSalaryExpPerDay > 0 THEN 'R' ELSE 'F' END
    FROM #TargetTable tt
    WHERE tt.OrderRef IS NOT NULL;

    -- Группа 2: RoadTax, Washing, CustomsDuty, Parking, Fine, Other
    UPDATE tt
    SET 
        tt.RoadTaxExpPerDay = CASE
            WHEN tt.OrderRef IS NULL THEN 0
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN tt.RealRoadTaxExpPerDay
            WHEN tt.RealRoadTaxExpPerDay > tt.FactRoadTaxExpPerDay THEN tt.RealRoadTaxExpPerDay
            ELSE tt.FactRoadTaxExpPerDay END,
        tt.RoadTaxExpPerDaySource = CASE
            WHEN tt.OrderRef IS NULL THEN NULL
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN 'R'
            WHEN tt.RealRoadTaxExpPerDay > tt.FactRoadTaxExpPerDay THEN 'R'
            WHEN tt.RealRoadTaxExpPerDay = tt.FactRoadTaxExpPerDay AND tt.RealRoadTaxExpPerDay > 0 THEN 'R'
            ELSE 'F' END,
        tt.WashingExpPerDay = CASE
            WHEN tt.OrderRef IS NULL THEN 0
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN tt.RealWashingExpPerDay
            WHEN tt.RealWashingExpPerDay > tt.FactWashingExpPerDay THEN tt.RealWashingExpPerDay
            ELSE tt.FactWashingExpPerDay END,
        tt.WashingExpPerDaySource = CASE
            WHEN tt.OrderRef IS NULL THEN NULL
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN 'R'
            WHEN tt.RealWashingExpPerDay > tt.FactWashingExpPerDay THEN 'R'
            WHEN tt.RealWashingExpPerDay = tt.FactWashingExpPerDay AND tt.RealWashingExpPerDay > 0 THEN 'R'
            ELSE 'F' END,
        tt.CustomsDutyExpPerDay = CASE
            WHEN tt.OrderRef IS NULL THEN 0
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN tt.RealCustomsDutyExpPerDay
            WHEN tt.RealCustomsDutyExpPerDay > tt.FactCustomsDutyExpPerDay THEN tt.RealCustomsDutyExpPerDay
            ELSE tt.FactCustomsDutyExpPerDay END,
        tt.CustomsDutyExpPerDaySource = CASE
            WHEN tt.OrderRef IS NULL THEN NULL
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN 'R'
            WHEN tt.RealCustomsDutyExpPerDay > tt.FactCustomsDutyExpPerDay THEN 'R'
            WHEN tt.RealCustomsDutyExpPerDay = tt.FactCustomsDutyExpPerDay AND tt.RealCustomsDutyExpPerDay > 0 THEN 'R'
            ELSE 'F' END,
        tt.ParkingExpPerDay = CASE
            WHEN tt.OrderRef IS NULL THEN 0
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN tt.RealParkingExpPerDay
            WHEN tt.RealParkingExpPerDay > tt.FactParkingExpPerDay THEN tt.RealParkingExpPerDay
            ELSE tt.FactParkingExpPerDay END,
        tt.ParkingExpPerDaySource = CASE
            WHEN tt.OrderRef IS NULL THEN NULL
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN 'R'
            WHEN tt.RealParkingExpPerDay > tt.FactParkingExpPerDay THEN 'R'
            WHEN tt.RealParkingExpPerDay = tt.FactParkingExpPerDay AND tt.RealParkingExpPerDay > 0 THEN 'R'
            ELSE 'F' END,
        tt.FineExpPerDay = CASE
            WHEN tt.OrderRef IS NULL THEN 0
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN tt.RealFineExpPerDay
            WHEN tt.RealFineExpPerDay > tt.FactFineExpPerDay THEN tt.RealFineExpPerDay
            ELSE tt.FactFineExpPerDay END,
        tt.FineExpPerDaySource = CASE
            WHEN tt.OrderRef IS NULL THEN NULL
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN 'R'
            WHEN tt.RealFineExpPerDay > tt.FactFineExpPerDay THEN 'R'
            WHEN tt.RealFineExpPerDay = tt.FactFineExpPerDay AND tt.RealFineExpPerDay > 0 THEN 'R'
            ELSE 'F' END,
        tt.OtherExpPerDay = CASE
            WHEN tt.OrderRef IS NULL THEN 0
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN tt.RealOtherExpPerDay
            WHEN tt.RealOtherExpPerDay > tt.FactOtherExpPerDay THEN tt.RealOtherExpPerDay
            ELSE tt.FactOtherExpPerDay END,
        tt.OtherExpPerDaySource = CASE
            WHEN tt.OrderRef IS NULL THEN NULL
            WHEN oef.EndFact < DATEADD(MONTH, -1, GETDATE()) THEN 'R'
            WHEN tt.RealOtherExpPerDay > tt.FactOtherExpPerDay THEN 'R'
            WHEN tt.RealOtherExpPerDay = tt.FactOtherExpPerDay AND tt.RealOtherExpPerDay > 0 THEN 'R'
            ELSE 'F' END
    FROM #TargetTable tt
    LEFT JOIN #OrderEndFact oef ON oef.OrderRef = tt.OrderRef;

    -- DriverSalary для пустых дней: источник NULL если оба 0
    UPDATE tt
    SET tt.DriverSalaryExpPerDaySource = CASE
            WHEN tt.RealDriverSalaryExpPerDay = 0 AND tt.FactDriverSalaryPerDay = 0 THEN NULL
            WHEN tt.RealDriverSalaryExpPerDay > 0 THEN 'R'
            ELSE 'F' END
    FROM #TargetTable tt
    WHERE tt.OrderRef IS NULL;

    -- =============================================
    -- 24. ExpensesPerDay + MarginPerDay (по отобранным)
    -- =============================================
    UPDATE tt
    SET tt.ExpensesPerDay = tt.FuelExpPerDay + tt.AdBlueExpPerDay + tt.RoadTaxExpPerDay
        + tt.DriverSalaryExpPerDay + tt.WashingExpPerDay + tt.CustomsDutyExpPerDay
        + tt.ParkingExpPerDay + tt.FineExpPerDay + tt.OtherExpPerDay,
        tt.MarginPerDay = tt.IncomePerDay
        - (tt.FuelExpPerDay + tt.AdBlueExpPerDay + tt.RoadTaxExpPerDay
           + tt.DriverSalaryExpPerDay + tt.WashingExpPerDay + tt.CustomsDutyExpPerDay
           + tt.ParkingExpPerDay + tt.FineExpPerDay + tt.OtherExpPerDay)
    FROM #TargetTable tt;

    -- =============================================
    -- 25. DELETE + INSERT в pbi.TargetTableReal
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
        IncomePerDay,
        FuelExpPerDay, FuelExpPerDaySource,
        AdBlueExpPerDay, AdBlueExpPerDaySource,
        RoadTaxExpPerDay, RoadTaxExpPerDaySource,
        DriverSalaryExpPerDay, DriverSalaryExpPerDaySource,
        WashingExpPerDay, WashingExpPerDaySource,
        CustomsDutyExpPerDay, CustomsDutyExpPerDaySource,
        ParkingExpPerDay, ParkingExpPerDaySource,
        FineExpPerDay, FineExpPerDaySource,
        OtherExpPerDay, OtherExpPerDaySource,
        ExpensesPerDay, MarginPerDay, BreakEvenPointPerDay, QuotaPerDay,
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
    DROP TABLE #FactOrderWeight;
    DROP TABLE #OrderEndFact;
    DROP TABLE #Statements;
    DROP TABLE #ExpensesByOrder;
    DROP TABLE #FactRows;
    DROP TABLE #FactSplit;
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
