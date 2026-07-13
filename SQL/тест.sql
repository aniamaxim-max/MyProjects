-- exec work.pbi.RefreshTargetTable '20260101', 'F'

/* !!!!!!!!!для джоба!!!!!!!!!
 declare @StartDate datetime
 set @StartDate = DATEADD(YEAR, -2, CAST(GETDATE() AS DATE))
 exec work.pbi.RefreshTargetTable @StartDate, 'F'
 
  declare @StartDate datetime
 set @StartDate = DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))
 exec work.pbi.RefreshTargetTable @StartDate, 'F'
*/

--IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'RefreshTargetTable' AND SCHEMA_NAME(schema_id) = 'pbi')
--    DROP PROCEDURE pbi.RefreshTargetTable;
--GO

--CREATE PROCEDURE pbi.RefreshTargetTable
--    @StartDateParam DATETIME,
--    @TypeParam char(1)
--AS
BEGIN
    SET NOCOUNT ON;

    declare @StartDateParam datetime, @TypeParam char(1)
    set @StartDateParam = '20260401'
    set @TypeParam = 'F' -- 'P'

    declare @StartDate datetime, @Type char(1)
    set @StartDate = DATEADD(MONTH, -1, CAST(@StartDateParam AS DATE))
    set @Type = @TypeParam + ''

    IF OBJECT_ID('tempdb..#WorkDays') IS NOT NULL 
	    DROP TABLE #WorkDays;

    create table #WorkDays(
		    OrderRef      VARCHAR(50),
		    [Order]		  VARCHAR(12),
		    StartDate	  DATE,
		    EndDate		  DATE,
		    EmptyBefore	  INT,
		    EmptyAfter	  INT,
		    FullStartDate DATE,
		    FullEndDate	  DATE
    );

    if @Type = 'F'
    begin
	    insert into #WorkDays
	    exec work.pbi.GetFactDays @StartDate 
    end 
    else 
    begin
	    insert into #WorkDays
	    exec work.pbi.GetPlanDays @StartDate
    end

    IF OBJECT_ID('tempdb..#AllOrders') IS NOT NULL 
	    DROP TABLE #AllOrders;

    CREATE TABLE #AllOrders (
	    OrderRef    VARCHAR(50),        
	    TruckRef    VARCHAR(50),
        DriverRef   VARCHAR(50),
	    StartResult DATETIME,
	    EndResult   DATETIME
    );

    ;with cte_Orders as (
	    select * from #WorkDays
    ),
    cte_Mixing as(
	    select *, ROW_NUMBER() OVER(PARTITION BY OrderReff ORDER BY HitchDate) AS RN
	    from (
		    select distinct OrderReff, FirstTruckReff, LastTruckReff, CAST(HitchDate as Date) as HitchDate
		    from pbi.v_Mixing
		    where OrderReff IN (SELECT OrderRef FROM #WorkDays) and @Type = 'F'
	    ) M
    ),
    cte_MaxMixing as(
	    select OrderReff, MAX(RN) as MaxRN
	    from cte_Mixing
	    group by OrderReff
    )
    Insert into #AllOrders (OrderRef, TruckRef, DriverRef, StartResult, EndResult)
SELECT 
    T.OrderRef,
    T.TruckRef,
    COALESCE(D.DriverReff, T.DriverRef) AS DriverRef,   -- на всякий случай
    T.StartResult,
    T.EndResult
FROM (
    -- 1. Старт первой перецепки
    SELECT 
        O.OrderRef,
        M.FirstTruckReff AS TruckRef,
        NULL AS DriverRef,
        O.FullStartDate AS StartResult,
        M.HitchDate AS EndResult
    FROM cte_Orders O
    JOIN cte_Mixing M ON O.OrderRef = M.OrderReff AND M.RN = 1

    UNION

    -- 2. Окончание последней перецепки
    SELECT 
        O.OrderRef,
        M.LastTruckReff AS TruckRef,
        NULL AS DriverRef,
        M.HitchDate AS StartResult,
        O.FullEndDate AS EndResult
    FROM cte_Orders O
    JOIN cte_MaxMixing MM ON O.OrderRef = MM.OrderReff
    JOIN cte_Mixing M ON O.OrderRef = M.OrderReff AND M.RN = MM.MaxRN

    UNION

    -- 3. Промежуточные перецепки
    SELECT 
        MStart.OrderReff,
        MEnd.FirstTruckReff AS TruckRef,
        NULL AS DriverRef,
        MStart.HitchDate AS StartResult,
        MEnd.HitchDate AS EndResult
    FROM cte_Mixing MStart
    JOIN cte_Mixing MEnd ON MStart.OrderReff = MEnd.OrderReff 
                       AND MStart.RN = MEnd.RN - 1

    UNION

    -- 4. Заказы без перецепок + все планы
    SELECT 
        O.OrderRef,
        DO.TruckReff AS TruckRef,
        DO.DriverReff AS DriverRef,
        O.FullStartDate AS StartResult,
        O.FullEndDate AS EndResult
    FROM cte_Orders O
    JOIN pbi.v_DimOrders DO ON DO.OrderRef = O.OrderRef
    WHERE (NOT EXISTS (SELECT 1 FROM pbi.v_Mixing M WHERE M.OrderReff = O.OrderRef) 
           OR @Type = 'P')

) T
INNER JOIN pbi.v_DimOrders D ON D.OrderRef = T.OrderRef

    IF OBJECT_ID('tempdb..#TargetTable') IS NOT NULL 
	    DROP TABLE #TargetTable;

    create table #TargetTable (
        TruckRef          varchar(50),
        TargetDate        datetime,
	    OrderRef          varchar(50),
        DriverRef         varchar(50),
	    StatementRef      varchar(50),
	    IsPaidStatement   bit not null default 1,
	    DurationStatement bit not null default 1,
	    DayPart           numeric(10,2) not null default 0.0,
        IncomePerDay      numeric(10,4) not null default 0.0,
	    ExpensesPerDayWithoutSalary numeric(10,4) not null default 0.0,
        DriverSalaryPerDay numeric(10,2) not null default 0.0,
        MarginPerDay      numeric(10,4) not null default 0.0,
	    BreakEvenPointPerDay numeric(10,4) not null default 0.0,
	    QuotaPerDay       numeric(10,4) not null default 0.0
    )

    insert #TargetTable(TruckRef, TargetDate, OrderRef, DriverRef)
    select TruckRef, CalDate, OrderRef, DriverRef  
    from #AllOrders AO
    --		inner join pbi.v_DimOrders DO on DO.OrderRef = AO.OrderRef 
	    inner join pbi.v_Calendar C on C.CalDate between AO.StartResult and AO.EndResult

    insert #TargetTable(TruckRef, TargetDate)
    select TruckReff, CalDate 
	    from pbi.v_Calendar C
		    cross join (
			    select distinct DT.TruckReff from pbi.v_DimTrucks DT
			    where DT.Description1 = 'Тягачі' and DT.Description2 = 'Робочі'
		    ) T
	    where CalDate >= @StartDate AND CalDate <= DATEADD(DAY, 10, CAST(GETDATE() AS DATE))
	      AND NOT EXists (Select 1 from #AllOrders A 
						    WHERE A.TruckRef = T.TruckReff 
						      and C.CalDate between A.StartResult and A.EndResult)
    ;WITH cte_Statuses AS (
        SELECT 
            CalDate, 
            TruckRef, 
            StatusRef, 
            ROW_NUMBER() OVER(PARTITION BY CalDate, TruckRef ORDER BY IdleDate DESC) AS RN
        FROM pbi.v_Statement s
            INNER JOIN pbi.v_Calendar c ON c.CalDate >= s.IdleStart AND c.CalDate <= s.IdleEnd AND c.CalDate >= @StartDate
    )
    UPDATE #TargetTable
    SET StatementRef = s.StatusRef
    FROM cte_Statuses s
    WHERE s.TruckRef = #TargetTable.TruckRef
      AND s.CalDate = #TargetTable.TargetDate
      AND s.RN = 1

    UPDATE i
    SET i.IsPaidStatement = 
		    CASE 
			    WHEN ST.StatementType4 = 'Без оплати' THEN 0 ELSE 1 END,
        i.DurationStatement = 
		    CASE 
			    WHEN ST.StatementType1 = 'Простій' THEN 0 ELSE 1 END
    FROM #TargetTable i
    LEFT JOIN pbi.v_StatementType ST 
        ON ST.StatementTypeRef = i.StatementRef     

    UPDATE p
    SET p.DayPart = 1.0 / td.Cnt
    FROM #TargetTable p
    INNER JOIN (
        SELECT 
            TruckRef,
            TargetDate,
            COUNT(*) AS Cnt
        FROM #TargetTable
        GROUP BY TruckRef, TargetDate
    ) td 
        ON td.TruckRef = p.TruckRef 
       AND td.TargetDate = p.TargetDate

    --UPDATE #TargetTable 
    --SET IncomePerDay = 0.0

    IF OBJECT_ID('tempdb..#OrderWeight') IS NOT NULL
        DROP TABLE #OrderWeight;

    SELECT 
        OrderRef,
        SUM(CASE WHEN DurationStatement = 1 THEN DayPart ELSE 0 END) AS TotalDayParts
    INTO #OrderWeight
    FROM #TargetTable
    GROUP BY OrderRef;

    UPDATE i
    SET i.IncomePerDay = 
        CASE 
            WHEN i.DurationStatement = 0 THEN 0.0
            WHEN ow.TotalDayParts > 0 THEN isnull(oc.SalesFactOrPlan, 0) * i.DayPart / ow.TotalDayParts
            ELSE 0.0
        END
    FROM #TargetTable i
    LEFT JOIN #OrderWeight ow ON ow.OrderRef = i.OrderRef
    LEFT JOIN pbi.v_OrderCost OC ON OC.OrderRef = i.OrderRef

    UPDATE e
    SET e.ExpensesPerDayWithoutSalary = 
        CASE 
            WHEN e.DurationStatement = 0 THEN 0.0
            WHEN ow.TotalDayParts > 0 THEN isnull(pe.SumMaterial, 0) * e.DayPart / ow.TotalDayParts
            ELSE 0.0
        END
    FROM #TargetTable e
    LEFT JOIN #OrderWeight ow ON ow.OrderRef = e.OrderRef
    LEFT JOIN (
        SELECT 
            CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26554_RRRef, 2) AS OrderRef,
            SUM(_AccumRg26553._Fld26565) - SUM(_AccumRg26553._Fld26566) AS SumMaterial
        FROM _AccumRg26553
        WHERE _Fld26556_RRRef NOT IN (0x9438B52C1CA5BDB511E67F083B490E5A, 0x9438B52C1CA5BDB511E67F083B490E5A)
            AND CAST(_AccumRg26553._Active AS bit) = 1
            AND _AccumRg26553._Fld26565 <> 0
        GROUP BY CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26554_RRRef, 2)
    ) pe ON pe.OrderRef = e.OrderRef

    UPDATE e
    SET e.DriverSalaryPerDay = 
        CASE 
            WHEN e.IsPaidStatement = 0 THEN 0.0
            ELSE isnull(ds.DriverSalaryPerDayEUR, 0) * e.DayPart
        END 
    FROM #TargetTable e
    LEFT JOIN pbi.v_DriverSalary ds ON ds.Driver = e.DriverRef

    UPDATE e
    SET e.MarginPerDay = e.IncomePerDay - e.ExpensesPerDayWithoutSalary - e.DriverSalaryPerDay
    FROM #TargetTable e

    UPDATE e
    SET e.BreakEvenPointPerDay =
        ISNULL(q.BreakEvenPoint * e.DayPart, 0)
    FROM #TargetTable e
    LEFT JOIN pbi.v_DimTrucks dt ON dt.TruckReff = e.TruckRef
    LEFT JOIN pbi.v_Quota q ON q.CompanyRef = dt.LastTruckCompanyReff AND MONTH(q.[Period]) = MONTH(e.TargetDate) and YEAR(q.[Period]) = YEAR(e.TargetDate)

    UPDATE e
    SET e.QuotaPerDay = ISNULL((CASE
        WHEN e.OrderRef is null THEN q.Quota
        WHEN pr.RouteType = 'Україна' AND do.ClientReff = 'ACEFD32FEC9A2DE011E680D1BDE456FD' THEN q.QuotaUkraineLinde
        WHEN pr.RouteType <> 'Україна' AND do.ClientReff = 'ACEFD32FEC9A2DE011E680D1BDE456FD' THEN q.QuotaEuropeLinde
        WHEN pr.RouteType = 'Україна' AND do.ClientReff <> 'ACEFD32FEC9A2DE011E680D1BDE456FD' THEN q.QuotaUkraine
        WHEN pr.RouteType <> 'Україна' AND do.ClientReff <> 'ACEFD32FEC9A2DE011E680D1BDE456FD' THEN q.QuotaEurope
        ELSE 0 END), 0) * e.DayPart
    FROM #TargetTable e
    LEFT JOIN pbi.v_DimTrucks dt ON dt.TruckReff = e.TruckRef
    LEFT JOIN pbi.v_Quota q ON q.CompanyRef = dt.LastTruckCompanyReff AND MONTH(q.[Period]) = MONTH(e.TargetDate) and YEAR(q.[Period]) = YEAR(e.TargetDate)
    LEFT JOIN pbi.v_DimOrders do ON do.OrderRef = e.OrderRef
    LEFT JOIN pbi.v_PivotRoute pr ON pr.PivotRouteRef = do.RouteReff    

	 --select * from #AllOrders where OrderRef = '80B802B31CC3E40111F11971B3D36F56'
    select t.*, do.[Order], p.PivotRouteName, dt.LegalNum from #TargetTable t
	left join pbi.v_DimOrders do on do.OrderRef = t.OrderRef
	left join pbi.v_PivotRoute p on p.PivotRouteRef = do.RouteReff
	left join pbi.v_DimTrucks dt on dt.TruckReff = t.TruckRef

 --   ----where TruckRef = 'B5FF02B31CC3E40111ED488D7AD77D96'
 --   ----where TargetDate between '20260301' and '20260331'
 --   where t.OrderRef = '80B802B31CC3E40111F11971B3D36F56'
    --order by TargetDate

    --IF (@Type = 'P')
    --BEGIN
    --    DELETE FROM pbi.TargetTablePlan WHERE TargetDate >= @StartDateParam

    --    INSERT INTO pbi.TargetTablePlan
    --    SELECT * FROM #TargetTable
    --    WHERE TargetDate >= @StartDateParam
    --END
    --ELSE 
    --BEGIN
    --    DELETE FROM pbi.TargetTableFact WHERE TargetDate >= @StartDateParam

    --    INSERT INTO pbi.TargetTableFact
    --    SELECT * FROM #TargetTable
    --    WHERE TargetDate >= @StartDateParam
    --END

    DROP TABLE #TargetTable
    DROP TABLE #AllOrders
    DROP TABLE #WorkDays
    DROP TABLE #OrderWeight
END
GO

