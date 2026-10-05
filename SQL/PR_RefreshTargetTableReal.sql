-- exec work.pbi.RefreshTargetTableReal '20260801'
-- select * from pbi.TargetTableReal where TargetDate >= '20260601' and OrderRef = '80B902B31CC3E40111F1A2CC49DD0C4A' order by TruckRef, TargetDate 

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
    -- 1. Источник дней на уровне заявки: "ПЛ" или "TargetTableFact".
    --    ПЛ — окончательный документ; берём его, если ВСЕ задачи всех
    --    ПЛ заявки имеют StartFact_RShT и EndFact_RShT, и есть хотя бы
    --    один завершённый сегмент (RouteIsInProgress = 0).
    --    posted/marked уже отфильтрованы в pbi.vb_RouteSheet.
    -- =============================================
    IF OBJECT_ID('tempdb..#PlOrders') IS NOT NULL DROP TABLE #PlOrders;

    SELECT t.OrderRef
    INTO #PlOrders
    FROM pbi.vb_RouteSheet r
    INNER JOIN pbi.vb_RouteSheetTask t ON t.RouteSheetRef = r.RouteSheetRef
    WHERE t.OrderRef <> 0x00000000000000000000000000000000
    GROUP BY t.OrderRef
    HAVING SUM(CASE WHEN t.StartFact_RShT IS NOT NULL AND t.EndFact_RShT IS NOT NULL THEN 1 ELSE 0 END) = COUNT(*)
       AND MAX(CASE WHEN r.RouteIsInProgress = 0 THEN 1 ELSE 0 END) = 1;

    CREATE CLUSTERED INDEX IX_PlOrders_Order ON #PlOrders(OrderRef);

    -- =============================================
    -- 1a. AllOrders из путевых листов (источник = ПЛ)
    --     По каждой ноге (RouteSheetRef): MIN/MAX факт-дат,
    --     машина/водитель — из ПЛ. Только заявки из #PlOrders.
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
    INNER JOIN #PlOrders po ON po.OrderRef = t.OrderRef
    WHERE t.OrderRef <> 0x00000000000000000000000000000000
    GROUP BY t.OrderRef, r.TruckRef, r.DriverRef, r.RouteSheetRef
    HAVING MAX(t.EndFact_RShT) >= @StartDate;

    CREATE INDEX IX_AO_Order ON #AllOrders(OrderRef);
    CREATE INDEX IX_AO_Truck_Start_End ON #AllOrders(TruckRef, StartResult, EndResult);

    -- =============================================
    -- 1b. FactOrders (источник = TargetTableFact)
    --     Заявки из факта, кроме тех, что уже пошли по ПЛ.
    -- =============================================
    IF OBJECT_ID('tempdb..#FactOrders') IS NOT NULL DROP TABLE #FactOrders;

    SELECT DISTINCT CONVERT(binary(16), f.OrderRef, 2) AS OrderRef
    INTO #FactOrders
    FROM pbi.TargetTableFact f
    WHERE f.TargetDate >= @StartDate
      AND f.OrderRef IS NOT NULL AND f.OrderRef <> ''
      AND CONVERT(binary(16), f.OrderRef, 2) NOT IN (SELECT OrderRef FROM #PlOrders);

    CREATE CLUSTERED INDEX IX_FactOrders_Order ON #FactOrders(OrderRef);

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
    SELECT OrderRef, TruckReff, DriverReff, ManagerReff, RouteReff, ClientReff, QuotaType
    INTO #DimOrders
    FROM pbi.vb_DimOrders
    WHERE OrderRef IN (SELECT OrderRef FROM #AllOrders UNION SELECT OrderRef FROM #FactOrders)
      AND Expedition = 0;
    CREATE CLUSTERED INDEX IX_DimOrders_Ref ON #DimOrders(OrderRef);

    IF OBJECT_ID('tempdb..#OrderCost') IS NOT NULL DROP TABLE #OrderCost;
    SELECT OrderRef, SalesFactOrPlan
    INTO #OrderCost
    FROM pbi.vb_OrderCost
    WHERE OrderRef IN (SELECT OrderRef FROM #AllOrders UNION SELECT OrderRef FROM #FactOrders);
    CREATE CLUSTERED INDEX IX_OC_Ref ON #OrderCost(OrderRef);

    IF OBJECT_ID('tempdb..#Quota') IS NOT NULL DROP TABLE #Quota;
    SELECT CompanyRef, BreakEvenPoint, Quota, QuotaUkraineLinde, QuotaEuropeLinde,
           QuotaUkraine, QuotaEurope, QuotaExport, QuotaImport, QuotaTDI, [Period]
    INTO #Quota
    FROM pbi.vb_Quota;
    CREATE INDEX IX_Quota_Company ON #Quota(CompanyRef);


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
        RowId             int identity(1,1),
        QuotaType         nvarchar(50),
        QuotaTypeEff      nvarchar(50),
        HasPrevTrip       bit,
        PrevQuotaType     nvarchar(50),
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
        CurManagerRef     binary(16),
        AddDownload       bit
    );

    -- Строки источника "Путевой лист"
    INSERT INTO #TargetTable(TruckRef, TargetDate, OrderRef, DriverRef)
    SELECT DISTINCT AO.TruckRef, C.CalDate, AO.OrderRef, AO.DriverRef
    FROM #AllOrders AO
    INNER JOIN pbi.v_Calendar C ON C.CalDate BETWEEN AO.StartResult AND AO.EndResult;

    -- Строки источника "TargetTableFact" (копируем только идентичность дня)
    INSERT INTO #TargetTable(TruckRef, TargetDate, OrderRef, DriverRef)
    SELECT DISTINCT fr.TruckRef, fr.TargetDate, fr.OrderRef, fr.DriverRef
    FROM #FactRows fr
    INNER JOIN #FactOrders fo ON fo.OrderRef = fr.OrderRef
    WHERE fr.OrderRef IS NOT NULL;

    CREATE INDEX IX_TT_Truck_Date ON #TargetTable(TruckRef, TargetDate);

    -- Пустые машино-дни — после строк ОБОИХ источников
    INSERT INTO #TargetTable(TruckRef, TargetDate)
    SELECT DT.TruckReff, C.CalDate
    FROM pbi.v_Calendar C
    CROSS JOIN #Trucks DT
    WHERE C.CalDate >= @StartDate AND C.CalDate <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE))
      AND NOT EXISTS (
          SELECT 1 FROM #TargetTable T
          WHERE T.TruckRef = DT.TruckReff AND T.TargetDate = C.CalDate
      );

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
    -- 11. OrderWeight (по заявкам обоих источников)
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
            WHEN de.ExpensesType = 'Fuel' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0)
            THEN e.Sum - CASE 
                WHEN e.ExpensesRef = 0x86F5B68AC35E4EB511E679CAA0EBCC7F 
                     AND dt.LastTruckCompany = N'Трімекс' 
                     AND (e.NDS IS NULL OR e.NDS = 0)
                THEN e.Sum * 0.2
                ELSE ISNULL(e.NDS, 0) END
            ELSE 0 END) AS FuelExpenses,
        SUM(CASE WHEN de.ExpensesType = 'AdBlue' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS AdBlueExpenses,
        SUM(CASE WHEN de.ExpensesType = 'RoadTax' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS RoadTaxExpenses,
        SUM(CASE WHEN de.ExpensesType = 'DriverSalary' AND e.DriverWork > 0 THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS DriverSalaryExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Washing' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS WashingExpenses,
        SUM(CASE WHEN de.ExpensesType = 'CustomsDuty' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS CustomsDutyExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Parking' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS ParkingExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Fine' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS FineExpenses,
        SUM(CASE WHEN de.ExpensesType = 'Other' AND (e.ExpensesRef <> 0x86F5B68AC35E4EB511E679CAA0EBCC81 OR e.DriverWork > 0) THEN e.Sum - ISNULL(e.NDS, 0) ELSE 0 END) AS OtherExpenses
    INTO #ExpensesByOrder
    FROM pbi.vb_Expenses e
    LEFT JOIN #DimExpenses de ON de.ExpRef = e.ExpensesRef
    LEFT JOIN #Trucks dt ON dt.TruckReff = e.TruckReff
    WHERE e.Date >= @StartDate
      AND e.OrderRef IN (SELECT OrderRef FROM #AllOrders UNION SELECT OrderRef FROM #FactOrders)
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
    -- 19. FactOrderWeight
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
    -- =============================================
    -- QuotaPerDay за типом рейсу (QuotaType)
    -- =============================================
    UPDATE tt
    SET tt.QuotaType = do.QuotaType
    FROM #TargetTable tt
    INNER JOIN #DimOrders do ON do.OrderRef = tt.OrderRef;

    IF OBJECT_ID('tempdb..#SeedTripType') IS NOT NULL DROP TABLE #SeedTripType;

    ;WITH cte_Seed AS (
        SELECT do.TruckReff AS TruckRef, do.QuotaType,
               ROW_NUMBER() OVER (PARTITION BY do.TruckReff
                   ORDER BY COALESCE(do.EndFact, do.EndPlan, do.OrderDate) DESC, do.OrderRef DESC) AS RN
        FROM pbi.vb_DimOrders do
        WHERE COALESCE(do.EndFact, do.EndPlan, do.OrderDate) < @StartDate
          AND COALESCE(do.EndFact, do.EndPlan, do.OrderDate) >= DATEADD(YEAR, -2, @StartDate)
          AND do.TruckReff IN (SELECT DISTINCT TruckRef FROM #TargetTable WHERE OrderRef IS NULL)
          AND do.Expedition = 0
    )
    SELECT TruckRef, QuotaType
    INTO #SeedTripType
    FROM cte_Seed
    WHERE RN = 1;

    CREATE CLUSTERED INDEX IX_SeedTripType ON #SeedTripType(TruckRef);

    IF OBJECT_ID('tempdb..#PrevTrip') IS NOT NULL DROP TABLE #PrevTrip;
    CREATE TABLE #PrevTrip (RowId int primary key, HasPrev bit, PrevQuotaType nvarchar(50));

    ;WITH cte_Last AS (
        SELECT RowId, TruckRef, TargetDate, OrderRef, QuotaType,
               MAX(CASE WHEN OrderRef IS NOT NULL THEN TargetDate END)
                   OVER (PARTITION BY TruckRef ORDER BY TargetDate
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LastTripDate
        FROM #TargetTable
    )
    INSERT INTO #PrevTrip (RowId, HasPrev, PrevQuotaType)
    SELECT L.RowId,
           MAX(CASE WHEN P.OrderRef IS NOT NULL THEN 1 ELSE 0 END),
           MAX(P.QuotaType)
    FROM cte_Last L
    LEFT JOIN #TargetTable P
        ON P.TruckRef = L.TruckRef
       AND P.TargetDate = L.LastTripDate
    GROUP BY L.RowId;

    UPDATE tt
    SET tt.HasPrevTrip = CASE WHEN pt.HasPrev = 1 OR sd.TruckRef IS NOT NULL THEN 1 ELSE 0 END,
        tt.PrevQuotaType = CASE WHEN pt.HasPrev = 1 THEN pt.PrevQuotaType
                                WHEN sd.TruckRef IS NOT NULL THEN sd.QuotaType
                                ELSE NULL END
    FROM #TargetTable tt
    LEFT JOIN #PrevTrip pt ON pt.RowId = tt.RowId
    LEFT JOIN #SeedTripType sd ON sd.TruckRef = tt.TruckRef;

    UPDATE tt
    SET tt.QuotaTypeEff =
        CASE
            WHEN tt.OrderRef IS NOT NULL THEN ISNULL(tt.QuotaType, N'Невідомо')
            WHEN st.StatementType2 = N'Ремонт' THEN N'Ремонт'
            WHEN tt.HasPrevTrip = 0 THEN N'Немає'
            ELSE
                CASE ISNULL(tt.PrevQuotaType, N'Невідомо')
                    WHEN N'Експорт' THEN N'Імпорт'
                    WHEN N'Європа' THEN N'Імпорт'
                    WHEN N'Імпорт' THEN N'Експорт'
                    WHEN N'Україна' THEN N'Україна'
                    WHEN N'Імпорт зріджені гази' THEN N'Україна зріджені гази'
                    WHEN N'Україна зріджені гази' THEN N'Імпорт зріджені гази'
                    WHEN N'TDI' THEN N'TDI'
                    ELSE N'Невідомо'
                END
        END
    FROM #TargetTable tt
    LEFT JOIN pbi.vb_StatementType st ON st.StatementTypeRef = tt.StatementRef;

    UPDATE tt
    SET 
        tt.BreakEvenPointPerDay = ISNULL(q.BreakEvenPoint * tt.DayPart, 0),
        tt.QuotaPerDay = ISNULL((CASE tt.QuotaTypeEff
            WHEN N'Імпорт' THEN q.QuotaImport
            WHEN N'Експорт' THEN q.QuotaExport
            WHEN N'Європа' THEN q.QuotaExport
            WHEN N'Україна' THEN q.QuotaUkraine
            WHEN N'TDI' THEN q.QuotaTDI
            WHEN N'Імпорт зріджені гази' THEN q.QuotaEuropeLinde
            WHEN N'Україна зріджені гази' THEN q.QuotaUkraineLinde
            WHEN N'Невідомо' THEN q.Quota
            ELSE 0 END), 0) * tt.DayPart
    FROM #TargetTable tt
    LEFT JOIN #Trucks dt ON dt.TruckReff = tt.TruckRef
    LEFT JOIN #Quota q ON q.CompanyRef = dt.LastTruckCompanyReff 
        AND MONTH(q.[Period]) = MONTH(tt.TargetDate) 
        AND YEAR(q.[Period]) = YEAR(tt.TargetDate)

    -- =============================================
    -- 23. Отбор Real/Fact по каждой паре расходов
    --     Группа 1 (Fuel, AdBlue, DriverSalary):
    --       real > 0 -> real, иначе fact
    --     Группа 2 (остальные):
    --       EndFact < GETDATE()-1 месяц -> real
    --       иначе max(real, fact), при равенстве -> real
    -- =============================================
    IF OBJECT_ID('tempdb..#OrderEndFact') IS NOT NULL DROP TABLE #OrderEndFact;

    SELECT OrderRef, EndFact, AddDownload
    INTO #OrderEndFact
    FROM pbi.vb_DimOrders
    WHERE OrderRef IN (SELECT OrderRef FROM #TargetTable WHERE OrderRef IS NOT NULL)
      AND Expedition = 0;

    CREATE CLUSTERED INDEX IX_OEF_Order ON #OrderEndFact(OrderRef);

    -- Заполняем AddDownload по всем заявкам (оба источника), пустые дни -> NULL
    UPDATE tt
    SET tt.AddDownload = oef.AddDownload
    FROM #TargetTable tt
    LEFT JOIN #OrderEndFact oef ON oef.OrderRef = tt.OrderRef;

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
        CONVERT(VARCHAR(MAX), CurManagerRef, 2) AS CurManagerRef,
        AddDownload
    FROM #TargetTable
    WHERE TargetDate >= @StartDateParam;

    -- =============================================
    -- Cleanup
    -- =============================================
    DROP TABLE #TargetTable;
    DROP TABLE #AllOrders;
    DROP TABLE #PlOrders;
    DROP TABLE #FactOrders;
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
    DROP TABLE #SeedTripType;
    DROP TABLE #PrevTrip;
    DROP TABLE #TruckManagerHistory;
    DROP TABLE #DriverSalary;
    DROP TABLE #DimExpenses;

END
GO
