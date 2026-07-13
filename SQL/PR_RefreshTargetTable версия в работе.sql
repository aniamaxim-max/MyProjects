-- exec work.pbi.RefreshTargetTable '20260401', 'R'

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

CREATE PROCEDURE pbi.RefreshTargetTable
    @StartDateParam DATETIME,
    @TypeParam char(1)
AS
BEGIN
    SET NOCOUNT ON;

    --declare @StartDateParam datetime, @TypeParam char(1)
    --set @StartDateParam = '20260201'
    --set @TypeParam = 'F' -- 'P'

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
    else if @Type = 'P'
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

	if @Type <> 'R'
	begin
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
		Insert into #AllOrders 
		Select T.OrderRef, TruckRef, DriverReff, CAST(FullStartDate AS DATE), CAST(EndResult AS DATE)
		from (
			-- перецепки старт
			Select O.OrderRef, M.FirstTruckReff as TruckRef, O.FullStartDate, M.HitchDate as EndResult
			from cte_Orders O
			inner join cte_Mixing M on O.OrderRef =  M.OrderReff and M.RN = 1

			union
			-- перецепки окончание
			Select O.OrderRef, M.LastTruckReff, M.HitchDate, O.FullEndDate
			from cte_Orders O
			inner join cte_MaxMixing MM on O.OrderRef = MM.OrderReff
			inner join cte_Mixing M on O.OrderRef =  M.OrderReff and M.RN = MM.MaxRN

			union
			-- перецепки промежуточные
			select MStart.OrderReff, MEnd.FirstTruckReff, MStart.HitchDate, MEnd.HitchDate
			from cte_Mixing MStart
			inner join cte_Mixing MEnd on MStart.OrderReff = MEnd.OrderReff and MStart.RN = MEnd.RN - 1

			union

			select O.OrderRef, DO.TruckReff, O.FullStartDate, FullEndDate
			from cte_Orders O
			inner join pbi.v_DimOrders DO on DO.OrderRef = O.OrderRef 
			where not exists(select * from pbi.v_Mixing M where O.OrderRef = M.OrderReff) or @Type = 'P'
		) T
		INNER JOIN pbi.v_DimOrders D ON D.OrderRef = T.OrderRef

	end
	else 
	begin
		Insert into #AllOrders
		select  
			t.OrderRef,
			r.TruckRef,
			r.DriverRef,
			MIN(t.StartFact_RShT) AS StartResult,
			MAX(t.EndFact_RShT) AS EndResult
		from pbi.v_RouteSheet r
		inner join pbi.v_RouteSheetTask t on r.RouteSheetRef = t.RouteSheetRef
		inner join pbi.v_DimOrders DO on DO.OrderRef = t.OrderRef
		where t.OrderRef <> '00000000000000000000000000000000' AND DO.OrderDate >= @StartDate

		group by t.OrderRef, r.TruckRef, r.DriverRef, r.RouteSheetRef
	end


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
	    QuotaPerDay       numeric(10,4) not null default 0.0,
		MainManagerRef    varchar(50),
		CurManagerRef     varchar(50)
    )

	CREATE NONCLUSTERED INDEX TargetTable_TruckRef_TargetDate_DriverRef ON #TargetTable ([TruckRef],[TargetDate],[DriverRef])

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

	UPDATE tt
	SET tt.MainManagerRef = (
		SELECT TOP 1 tm.ManagerRef
		FROM pbi.v_TruckManagerHistory tm
		WHERE tm.TruckRef = tt.TruckRef
		  AND tm.PeriodStart <= tt.TargetDate
		ORDER BY tm.PeriodStart DESC
	)
	FROM #TargetTable tt

	UPDATE #TargetTable
    SET CurManagerRef = do.ManagerReff
    FROM pbi.v_DimOrders do
    WHERE do.OrderRef = #TargetTable.OrderRef


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
        WHERE _Fld26556_RRRef NOT IN (0x9438B52C1CA5BDB511E67F083B490E5A, 0x8FC8E82DAA1C02A111EBB472B3720821)
            AND CAST(_AccumRg26553._Active AS bit) = 1
            AND _AccumRg26553._Fld26565 <> 0
        GROUP BY CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26554_RRRef, 2)
    ) pe ON pe.OrderRef = e.OrderRef

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
            WHEN e.IsPaidStatement = 0 THEN isnull(ds.DriverTaxEUR, 0)
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


    --select * from pbi.TargetTableFACT
    --where TruckRef = '9CD602B31CC3E40111E7BA4609A1B880'
    --and TargetDate between '20260501' and '20260531'
    --where OrderRef = '80B902B31CC3E40111F129C5088634C2'
    --order by TargetDate

    IF (@Type = 'P')
    BEGIN
        DELETE FROM pbi.TargetTablePlan WHERE TargetDate >= @StartDateParam

        INSERT INTO pbi.TargetTablePlan
        SELECT * FROM #TargetTable
        WHERE TargetDate >= @StartDateParam
    END
    ELSE IF (@Type = 'F')
    BEGIN
        DELETE FROM pbi.TargetTableFact WHERE TargetDate >= @StartDateParam

        INSERT INTO pbi.TargetTableFact
        SELECT * FROM #TargetTable
        WHERE TargetDate >= @StartDateParam
    END
	ELSE 
	BEGIN
		SELECT * from #TargetTable where TruckRef = '9CD602B31CC3E40111E7BA43D6B8F430' order by TargetDate
	END

    DROP TABLE #TargetTable
    DROP TABLE #AllOrders
    DROP TABLE #WorkDays
    DROP TABLE #OrderWeight
END
GO

