-- exec work.pbi.RefreshTargetTable '20260101', 'F'
-- select * from pbi.TargetTableFact /*where OrderRef = '80B902B31CC3E40111F15A91A354A473'*/
-- where tRUCKRef = '8FC8E82DAA1C02A111EBC794BE09EECD' AND TARGETDATE >= '20260601' order by TargetDate desc

/* !!!!!!!!!для джоба!!!!!!!!!
 declare @StartDate datetime
 set @StartDate = DATEADD(YEAR, -2, CAST(GETDATE() AS DATE))
 exec work.pbi.RefreshTargetTable @StartDate, 'F';
 exec work.pbi.RefreshTargetTable @StartDate, 'P'
 
  declare @StartDate datetime
 set @StartDate = DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))
 exec work.pbi.RefreshTargetTable @StartDate, 'F';
 exec work.pbi.RefreshTargetTable @StartDate, 'P'
*/

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'RefreshTargetTable' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.RefreshTargetTable;
GO

CREATE PROCEDURE [pbi].[RefreshTargetTable]
    @StartDateParam DATETIME,
    @TypeParam char(1)
AS
BEGIN
    SET NOCOUNT ON;

    --declare @StartDateParam datetime, @TypeParam char(1)
    --set @StartDateParam = '20260615'
    --set @TypeParam = 'F' -- 'P'

    declare @StartDate datetime, @Type char(1)
    set @StartDate = DATEADD(MONTH, -1, CAST(@StartDateParam AS DATE))
    set @Type = @TypeParam + ''

    IF OBJECT_ID('tempdb..#WorkDays') IS NOT NULL 
	    DROP TABLE #WorkDays;

    create table #WorkDays(
		    OrderRef      binary(16),
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
	    exec work.pbi.GetFactDaysBinary @StartDate 
    end 
    else 
    begin
	    insert into #WorkDays
	    exec work.pbi.GetPlanDaysBinary @StartDate
    end

	IF OBJECT_ID('tempdb..#DimOrders') IS NOT NULL 
		DROP TABLE #DimOrders;

	CREATE TABLE #DimOrders (
		OrderRef binary(16), 
		TruckReff binary(16), 
		DriverReff binary(16), 
		ManagerReff binary(16), 
		RouteReff binary(16), 
		ClientReff binary(16)
	);

	INSERT INTO #DimOrders
	SELECT OrderRef, TruckReff, DriverReff, ManagerReff, RouteReff, ClientReff	
	FROM pbi.vb_DimOrders
	WHERE OrderRef IN (SELECT OrderRef FROM #WorkDays);

	CREATE INDEX IX_DimOrders_OrderRef ON #DimOrders(OrderRef);

	IF OBJECT_ID('tempdb..#DriverSalary') IS NOT NULL 
	    DROP TABLE #DriverSalary;

	CREATE TABLE #DriverSalary (
		Driver   binary(16),
		[Period] datetime,
		DriverSalaryPerDayEUR decimal(38,6)
	)
	
	CREATE CLUSTERED INDEX IX_#DriverSalary_Driver_Period ON #DriverSalary (Driver, [Period] DESC);

	insert into #DriverSalary
	SELECT Driver, [Period], DriverSalaryPerDayEUR		
	FROM pbi.vb_DriverSalaryFull src
	WHERE src.[Period] >= DATEADD(Month, -1, @StartDate)-- and Driver =0x80B702B31CC3E40111F0CAABB9D82B64


    IF OBJECT_ID('tempdb..#AllOrders') IS NOT NULL 
	    DROP TABLE #AllOrders;

	CREATE TABLE #AllOrders (
	    OrderRef    binary(16),        
	    TruckRef    binary(16),
        DriverRef   binary(16),
	    StartResult DATETIME,
	    EndResult   DATETIME
    );

	IF OBJECT_ID('tempdb..#Statements') IS NOT NULL DROP TABLE #Statements;

	SELECT DISTINCT
		CalDate,
		TruckRef,
		StatusRef
	INTO #Statements
	FROM (
		SELECT 
			CalDate,
			TruckRef,
			StatusRef,
			ROW_NUMBER() OVER(PARTITION BY CalDate, TruckRef ORDER BY IdleDate DESC) AS RN
		FROM pbi.vb_Statement s
		INNER JOIN pbi.v_Calendar c 
			ON c.CalDate >= s.IdleStart 
			AND c.CalDate <= s.IdleEnd 
			AND c.CalDate >= @StartDate
			AND s.IdleStartRaw >= DATEADD(YEAR, 2000, @StartDate)
	) x
	WHERE RN = 1;

	CREATE INDEX IX_Statements_Truck_Date ON #Statements(TruckRef, CalDate) INCLUDE(StatusRef);


    ;with cte_Orders as (
	    select * from #WorkDays
    ),
    cte_Mixing as(
	    select *, ROW_NUMBER() OVER(PARTITION BY OrderReff ORDER BY HitchDate) AS RN
	    from (
		    select distinct OrderReff, FirstTruckReff, LastTruckReff, FirstDriverReff, LastDriverReff, CAST(HitchDate as Date) as HitchDate
		    from pbi.vb_Mixing
		    where OrderReff IN (SELECT OrderRef FROM #WorkDays) and @Type = 'F'
	    ) M
    ),
    cte_MaxMixing as(
	    select OrderReff, MAX(RN) as MaxRN
	    from cte_Mixing
	    group by OrderReff
    )
    Insert into #AllOrders 
    Select T.OrderRef, T.TruckRef, T.DriverReff, CAST(T.FullStartDate AS DATE), CAST(T.EndResult AS DATE)
    from (
	    -- перецепки старт
	    Select O.OrderRef, M.FirstTruckReff as TruckRef, M.FirstDriverReff as DriverReff, O.FullStartDate, M.HitchDate as EndResult
	    from cte_Orders O
	    inner join cte_Mixing M on O.OrderRef =  M.OrderReff and M.RN = 1

	    union
	    -- перецепки окончание
	    Select O.OrderRef, M.LastTruckReff as TruckRef, M.LastDriverReff as DriverReff, M.HitchDate as FullStartDate, O.FullEndDate as EndResult
	    from cte_Orders O
	    inner join cte_MaxMixing MM on O.OrderRef = MM.OrderReff
	    inner join cte_Mixing M on O.OrderRef =  M.OrderReff and M.RN = MM.MaxRN

	    union
	    -- перецепки промежуточные
	    select MStart.OrderReff, MEnd.FirstTruckReff as TruckRef, MEnd.FirstDriverReff as DriverReff, MStart.HitchDate as FullStartDate, MEnd.HitchDate as EndResult
	    from cte_Mixing MStart
	    inner join cte_Mixing MEnd on MStart.OrderReff = MEnd.OrderReff and MStart.RN = MEnd.RN - 1

	    union

	    select O.OrderRef, DO.TruckReff as TruckRef, DO.DriverReff as DriverReff, O.FullStartDate, O.FullEndDate as EndResult
	    from cte_Orders O
	    inner join #DimOrders DO on DO.OrderRef = O.OrderRef
	    where not exists(select * from pbi.vb_Mixing M where O.OrderRef = M.OrderReff) or @Type = 'P'
    ) T
    INNER JOIN #DimOrders D ON D.OrderRef = T.OrderRef

    IF OBJECT_ID('tempdb..#TargetTable') IS NOT NULL 
	    DROP TABLE #TargetTable;

    create table #TargetTable (
        TruckRef          binary(16),
        TargetDate        datetime,
	    OrderRef          binary(16),
        DriverRef         binary(16),
	    StatementRef      binary(16),
		IsPaidStatement   bit not null default 1,
	    DurationStatement bit not null default 1,
	    DayPart           numeric(10,2) not null default 0.0,
        IncomePerDay      numeric(10,4) not null default 0.0,
	    ExpensesPerDayWithoutSalary numeric(10,4) not null default 0.0,
        DriverSalaryPerDay numeric(10,2) not null default 0.0,
        MarginPerDay      numeric(10,4) not null default 0.0,
	    BreakEvenPointPerDay numeric(10,4) not null default 0.0,
	    QuotaPerDay       numeric(10,4) not null default 0.0,
		MainManagerRef    binary(16),
		CurManagerRef     binary(16)
    )

	CREATE NONCLUSTERED INDEX TargetTable_TruckRef_TargetDate_DriverRef ON #TargetTable ([TruckRef],[TargetDate],[DriverRef])

    insert #TargetTable(TruckRef, TargetDate, OrderRef, DriverRef)
    select TruckRef, CalDate, OrderRef, DriverRef  
    from #AllOrders AO
    --		inner join pbi.vb_DimOrders DO on DO.OrderRef = AO.OrderRef 
	    inner join pbi.v_Calendar C on C.CalDate between AO.StartResult and AO.EndResult

    insert #TargetTable(TruckRef, TargetDate)
    select TruckReff, CalDate 
	    from pbi.v_Calendar C
		    cross join (
			    select distinct DT.TruckReff from pbi.vb_DimTrucks DT
			    where DT.Description1 = 'Тягачі' and DT.Description2 = 'Робочі'
		    ) T
	    where CalDate >= @StartDate AND CalDate <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE))
	      AND NOT EXists (Select 1 from #AllOrders A 
						    WHERE A.TruckRef = T.TruckReff 
						      and C.CalDate between A.StartResult and A.EndResult)
    --;WITH cte_Statuses AS (
    --    SELECT 
    --        CalDate, 
    --        TruckRef, 
    --        StatusRef, 
    --        ROW_NUMBER() OVER(PARTITION BY CalDate, TruckRef ORDER BY IdleDate DESC) AS RN
    --    FROM pbi.vb_Statement s
    --        INNER JOIN pbi.v_Calendar c ON c.CalDate >= s.IdleStart AND c.CalDate <= s.IdleEnd AND c.CalDate >= @StartDate
    --)
    UPDATE #TargetTable
	SET StatementRef = s.StatusRef
	FROM #Statements s
	WHERE s.TruckRef = #TargetTable.TruckRef
	  AND s.CalDate = #TargetTable.TargetDate

	UPDATE tt
	SET tt.MainManagerRef = (
		SELECT TOP 1 tm.ManagerRef
		FROM pbi.vb_TruckManagerHistory tm
		WHERE tm.TruckRef = tt.TruckRef
		  AND tm.PeriodStart <= tt.TargetDate
		ORDER BY tm.PeriodStart DESC
	)
	FROM #TargetTable tt

	UPDATE #TargetTable
    SET CurManagerRef = do.ManagerReff
    FROM #DimOrders do
    WHERE do.OrderRef = #TargetTable.OrderRef


    UPDATE i
    SET i.IsPaidStatement = 
		    CASE 
			    WHEN ST.StatementType4 = 'Без оплати' THEN 0 ELSE 1 END,
        i.DurationStatement = 
		    CASE 
			    WHEN ST.StatementType1 = 'Простій' THEN 0 ELSE 1 END
    FROM #TargetTable i
    LEFT JOIN pbi.vb_StatementType ST 
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

	CREATE TABLE #OrderWeight (
		OrderRef binary(16),
		TotalDayParts numeric(10,2)
	)

    INSERT INTO #OrderWeight
	SELECT 
        OrderRef,
        SUM(CASE WHEN DurationStatement = 1 THEN DayPart ELSE 0 END) AS TotalDayParts
    FROM #TargetTable
    GROUP BY OrderRef;
	CREATE INDEX IX_OrderWeight_OrderRef ON #OrderWeight(OrderRef);

    UPDATE i
    SET i.IncomePerDay = 
        CASE 
            WHEN i.DurationStatement = 0 THEN 0.0
            WHEN ow.TotalDayParts > 0 THEN isnull(oc.SalesFactOrPlan, 0) * i.DayPart / ow.TotalDayParts
            ELSE 0.0
        END
    FROM #TargetTable i
    LEFT JOIN #OrderWeight ow ON ow.OrderRef = i.OrderRef
    LEFT JOIN pbi.vb_OrderCost OC ON OC.OrderRef = i.OrderRef

	IF OBJECT_ID('tempdb..#MaterialCosts') IS NOT NULL DROP TABLE #MaterialCosts;

	SELECT 
		_Fld26554_RRRef AS OrderRef,
		SUM(_Fld26565) - SUM(_Fld26566) AS SumMaterial
	INTO #MaterialCosts
	FROM _AccumRg26553
	WHERE _Fld26556_RRRef NOT IN (0x9438B52C1CA5BDB511E67F083B490E5A, 0x8FC8E82DAA1C02A111EBB472B3720821)
	  AND CAST(_Active AS bit) = 1
	  AND _Fld26565 <> 0
	GROUP BY _Fld26554_RRRef;

	CREATE INDEX IX_MaterialCosts_OrderRef ON #MaterialCosts(OrderRef);

    UPDATE e
    SET e.ExpensesPerDayWithoutSalary = 
        CASE 
            WHEN e.DurationStatement = 0 THEN 0.0
            WHEN ow.TotalDayParts > 0 THEN isnull(pe.SumMaterial, 0) * e.DayPart / ow.TotalDayParts
            ELSE 0.0
        END
    FROM #TargetTable e
    LEFT JOIN #OrderWeight ow ON ow.OrderRef = e.OrderRef
	LEFT JOIN #MaterialCosts pe ON pe.OrderRef = e.OrderRef

		;with cte_LastDriver as (
		select T.TruckRef, T.TargetDate, D.LastDriver 
		from #TargetTable T 
		cross apply (
			select top 1 D.DriverRef as LastDriver
			from #TargetTable D
			where T.TruckRef = D.TruckRef and D.DriverRef is not null  and D.DriverRef <> 0x0 and D.TargetDate < T.TargetDate
			order by D.TargetDate
		) D
		where DriverRef is null
	)
	update #TargetTable
	set DriverRef = LastDriver
	from cte_LastDriver c
	where #TargetTable.TruckRef = c.TruckRef and #TargetTable.TargetDate = c.TargetDate and #TargetTable.DriverRef is null

	UPDATE e
	SET e.DriverSalaryPerDay = 
		CASE 
			WHEN e.IsPaidStatement = 0 THEN 0.0
			ELSE isnull(ds.DriverSalaryPerDayEUR, 0) * e.DayPart
		END 
	FROM #TargetTable e
	OUTER APPLY (
		SELECT TOP 1 src.DriverSalaryPerDayEUR
		FROM #DriverSalary src
		WHERE src.Driver = e.DriverRef
		  AND src.[Period] <= e.TargetDate
		ORDER BY src.[Period] DESC
	) ds

    UPDATE e
    SET e.MarginPerDay = e.IncomePerDay - e.ExpensesPerDayWithoutSalary - e.DriverSalaryPerDay
    FROM #TargetTable e

    UPDATE e
	SET 
		e.BreakEvenPointPerDay = ISNULL(q.BreakEvenPoint * e.DayPart, 0),
		e.QuotaPerDay = ISNULL((CASE
			WHEN pr.RouteType = 'Україна' AND do.ClientReff = 0xACEFD32FEC9A2DE011E680D1BDE456FD THEN q.QuotaUkraineLinde
			WHEN pr.RouteType <> 'Україна' AND do.ClientReff = 0xACEFD32FEC9A2DE011E680D1BDE456FD THEN q.QuotaEuropeLinde
			WHEN dt.Description3 = 'Україна' THEN q.QuotaUkraine
			WHEN dt.Description3 IN ('Європа', 'Трімекс') THEN q.QuotaEurope
			ELSE 0 END), 0) * e.DayPart
	FROM #TargetTable e
	LEFT JOIN pbi.vb_DimTrucks dt ON dt.TruckReff = e.TruckRef
	LEFT JOIN pbi.vb_Quota q ON q.CompanyRef = dt.LastTruckCompanyReff 
		AND MONTH(q.[Period]) = MONTH(e.TargetDate) 
		AND YEAR(q.[Period]) = YEAR(e.TargetDate)
	LEFT JOIN #DimOrders do ON do.OrderRef = e.OrderRef
	LEFT JOIN pbi.vb_PivotRoute pr ON pr.PivotRouteRef = do.RouteReff  


    --select * from #TargetTable
    --where TruckRef = '9CD602B31CC3E40111E7BA4609A1B880'
    --and TargetDate between '20260501' and '20260531'
    --where OrderRef = '80B902B31CC3E40111F129C5088634C2'
    --order by TargetDate

    IF (@Type = 'P')
    BEGIN
        DELETE FROM pbi.TargetTablePlan WHERE TargetDate >= @StartDateParam
		
        INSERT INTO pbi.TargetTablePlan
        SELECT 
			CONVERT(VARCHAR(MAX), TruckRef, 2) AS TruckRef,
			TargetDate,
			CONVERT(VARCHAR(MAX), OrderRef, 2) AS OrderRef,
			CONVERT(VARCHAR(MAX), DriverRef, 2) AS DriverRef,
			CONVERT(VARCHAR(MAX), StatementRef, 2) AS StatementRef,
			IsPaidStatement,
			DurationStatement,
			DayPart,
			IncomePerDay,
			ExpensesPerDayWithoutSalary,
			DriverSalaryPerDay,
			MarginPerDay,
			BreakEvenPointPerDay,
			QuotaPerDay,
			CONVERT(VARCHAR(MAX), MainManagerRef, 2) AS MainManagerRef,
			CONVERT(VARCHAR(MAX), CurManagerRef, 2) AS CurManagerRef
		FROM #TargetTable
        WHERE TargetDate >= @StartDateParam
    END
    ELSE 
    BEGIN
        DELETE FROM pbi.TargetTableFact WHERE TargetDate >= @StartDateParam

        INSERT INTO pbi.TargetTableFact
        SELECT 
			CONVERT(VARCHAR(MAX), TruckRef, 2) AS TruckRef,
			TargetDate,
			CONVERT(VARCHAR(MAX), OrderRef, 2) AS OrderRef,
			CONVERT(VARCHAR(MAX), DriverRef, 2) AS DriverRef,
			CONVERT(VARCHAR(MAX), StatementRef, 2) AS StatementRef,
			IsPaidStatement,
			DurationStatement,
			DayPart,
			IncomePerDay,
			ExpensesPerDayWithoutSalary,
			DriverSalaryPerDay,
			MarginPerDay,
			BreakEvenPointPerDay,
			QuotaPerDay,
			CONVERT(VARCHAR(MAX), MainManagerRef, 2) AS MainManagerRef,
			CONVERT(VARCHAR(MAX), CurManagerRef, 2) AS CurManagerRef
		FROM #TargetTable
        WHERE TargetDate >= @StartDateParam
    END

    DROP TABLE #TargetTable
    DROP TABLE #AllOrders
    DROP TABLE #WorkDays
    DROP TABLE #OrderWeight
	DROP TABLE #DimOrders
	DROP TABLE #Statements
	DROP TABLE #MaterialCosts
	DROP TABLE #DriverSalary

END
GO
