-- exec pbi.FreeCar
-- select * from pbi.FreeCars
/*
SELECT * 
FROM OPENQUERY(LOOPBACK, 
'
    EXEC work.pbi.FreeCar 
    WITH RESULT SETS 
    (
        (
            TruckReff VARCHAR(MAX),
            LegalNum  VARCHAR(MAX),
            Manager   VARCHAR(MAX),
			Counter   INT,
            Status    VARCHAR(MAX),
			QuotaIsDone NUMERIC(10,2),
			GeoZone   VARCHAR(MAX)
        )
    )
');
*/
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'FreeCar' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.FreeCar;
GO

Create PROCEDURE pbi.FreeCar AS
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF

	IF OBJECT_ID('tempdb..#Repairs') IS NOT NULL 
		DROP TABLE #Repairs;

	CREATE TABLE #Repairs (
		TruckRef    VARCHAR(MAX),
		Remont0		INT,
		Remont1		INT,
		Remont2		INT,
		Remont3		INT,
		Remont4		INT,
		Remont5		INT,
		Remont6		INT,
		Remont7		INT,
		Remont8		INT,
		Remont9		INT
	);

	INSERT INTO #Repairs	
	select D.TruckReff, 
		SUM(CASE WHEN DayNum = 0 THEN 1 ELSE 0 END) AS Remont0,
		SUM(CASE WHEN DayNum = 1 THEN 1 ELSE 0 END) AS Remont1,
		SUM(CASE WHEN DayNum = 2 THEN 1 ELSE 0 END) AS Remont2,
		SUM(CASE WHEN DayNum = 3 THEN 1 ELSE 0 END) AS Remont3,
		SUM(CASE WHEN DayNum = 4 THEN 1 ELSE 0 END) AS Remont4,
		SUM(CASE WHEN DayNum = 5 THEN 1 ELSE 0 END) AS Remont5,
		SUM(CASE WHEN DayNum = 6 THEN 1 ELSE 0 END) AS Remont6,
		SUM(CASE WHEN DayNum = 7 THEN 1 ELSE 0 END) AS Remont7,
		SUM(CASE WHEN DayNum = 8 THEN 1 ELSE 0 END) AS Remont8,
		SUM(CASE WHEN DayNum = 9 THEN 1 ELSE 0 END) AS Remont9
	from pbi.v_DimTrucks D 
		LEFT JOIN (
			select TruckRef, DayNum			
			from 
			(
				Select CalDate, TruckRef, StatusRef, ROW_NUMBER() OVER(PARTITION BY TruckRef, CalDate ORDER BY IdleDate desc) as RN,
					DATEDIFF(DAY, CAST(Getdate() as DATE), CalDate) as DayNum
				from pbi.v_Statement as S
					inner join pbi.v_Calendar C on C.CalDate between IdleStart and IdleEnd
				where CalDate >= CAST(Getdate() as DATE)
			) T
			inner join pbi.v_StatementType ST ON ST.StatementTypeRef = T.StatusRef
			where RN = 1 and StatementType2 = 'Ремонт'		
		) T ON D.TruckReff = T.TruckRef AND D.Active = 1
	group by D.TruckReff

	IF OBJECT_ID('tempdb..#Orders') IS NOT NULL 
		DROP TABLE #Orders;

	CREATE TABLE #Orders (
		OrderRef    VARCHAR(MAX),
		[Order]     NCHAR(11),
		TruckRef    VARCHAR(MAX),
		StartResult DATETIME,
		EndResult   DATETIME
	);

	INSERT INTO #Orders
	select OrderRef, [Order], TruckReff, 
		case when StartFact IS NOT Null then StartFact else StartPlan end as 'StartResult',
		case when EndFact IS NOT Null then EndFact else EndPlan end as 'EndResult'
	from pbi.v_DimOrders
	where OrderDate >= DATEADD(MONTH, -2, GETDATE())
	and CAST(DeleteMark as bit) = 0
	and (OrderStatment <> 'Отказано' or OrderStatment <> 'Отказано клиентом')
	and TechOrder = 0
	and Expedition = 0

	IF OBJECT_ID('tempdb..#AllOrders') IS NOT NULL 
		DROP TABLE #AllOrders;

	CREATE TABLE #AllOrders (
		OrderRef    VARCHAR(MAX),
		TruckRef    VARCHAR(MAX),
		StartResult DATETIME,
		EndResult   DATETIME
	);

	;with cte_Orders as (
		select * from #Orders
	),
	cte_Mixing as(
		select *, ROW_NUMBER() OVER(PARTITION BY OrderReff ORDER BY HitchDate) AS RN
		from pbi.v_Mixing
	),
	cte_MaxMixing as(
		select OrderReff, MAX(RN) as MaxRN
		from cte_Mixing
		group by OrderReff
	)
	Insert into #AllOrders 
	Select OrderRef, TruckRef, CAST(StartResult AS DATE), CAST(EndResult AS DATE)
	from (
		-- перецепки старт
		Select O.OrderRef, M.FirstTruckReff as TruckRef, O.StartResult, M.HitchDate as EndResult
		from cte_Orders O
		inner join cte_Mixing M on O.OrderRef =  M.OrderReff and M.RN = 1

		union
		-- перецепки окончание
		Select O.OrderRef, M.LastTruckReff, M.HitchDate, O.EndResult
		from cte_Orders O
		inner join cte_MaxMixing MM on O.OrderRef = MM.OrderReff
		inner join cte_Mixing M on O.OrderRef =  M.OrderReff and M.RN = MM.MaxRN

		union
		-- перецепки промежуточные
		select MStart.OrderReff, MEnd.FirstTruckReff, MStart.HitchDate, MEnd.HitchDate
		from cte_Mixing MStart
		inner join cte_Mixing MEnd on MStart.OrderReff = MEnd.OrderReff and MStart.RN = MEnd.RN - 1

		union

		select OrderRef, TruckRef, StartResult, EndResult
		from cte_Orders O
		where not exists(select * from pbi.v_Mixing M where O.OrderRef = M.OrderReff)
	) T

	;with cte_DimTrucks as(
		select VT.TruckReff, LegalNum, Manager, cast(GETDATE() as Date) as ReportDate 
		from pbi.v_DimTrucks VT
		left join pbi.v_TruckManager VTM on VT.TruckReff = VTM.TruckReff
		where VT.Active = 1
	),
	cte_AllCounts as(
		Select T.TruckReff, LegalNum, Manager, 
			count(DISTINCT O0.OrderRef) as Count0,
			count(DISTINCT O1.OrderRef) as Count1,
			count(DISTINCT O2.OrderRef) as Count2,
			count(DISTINCT O3.OrderRef) as Count3,
			count(DISTINCT O4.OrderRef) as Count4,
			count(DISTINCT O5.OrderRef) as Count5,
			count(DISTINCT O6.OrderRef) as Count6,
			count(DISTINCT O7.OrderRef) as Count7,
			count(DISTINCT O8.OrderRef) as Count8,
			count(DISTINCT O9.OrderRef) as Count9
		from cte_DimTrucks T
			left join #AllOrders O0 on O0.TruckRef = T.TruckReff and DATEADD(DAY, 0, T.ReportDate) BETWEEN O0.StartResult AND O0.EndResult
			left join #AllOrders O1 on O1.TruckRef = T.TruckReff and DATEADD(DAY, 1, T.ReportDate) BETWEEN O1.StartResult AND O1.EndResult
			left join #AllOrders O2 on O2.TruckRef = T.TruckReff and DATEADD(DAY, 2, T.ReportDate) BETWEEN O2.StartResult AND O2.EndResult
			left join #AllOrders O3 on O3.TruckRef = T.TruckReff and DATEADD(DAY, 3, T.ReportDate) BETWEEN O3.StartResult AND O3.EndResult
			left join #AllOrders O4 on O4.TruckRef = T.TruckReff and DATEADD(DAY, 4, T.ReportDate) BETWEEN O4.StartResult AND O4.EndResult
			left join #AllOrders O5 on O5.TruckRef = T.TruckReff and DATEADD(DAY, 5, T.ReportDate) BETWEEN O5.StartResult AND O5.EndResult
			left join #AllOrders O6 on O6.TruckRef = T.TruckReff and DATEADD(DAY, 6, T.ReportDate) BETWEEN O6.StartResult AND O6.EndResult
			left join #AllOrders O7 on O7.TruckRef = T.TruckReff and DATEADD(DAY, 7, T.ReportDate) BETWEEN O7.StartResult AND O7.EndResult
			left join #AllOrders O8 on O8.TruckRef = T.TruckReff and DATEADD(DAY, 8, T.ReportDate) BETWEEN O8.StartResult AND O8.EndResult
			left join #AllOrders O9 on O9.TruckRef = T.TruckReff and DATEADD(DAY, 9, T.ReportDate) BETWEEN O9.StartResult AND O9.EndResult
		group by T.TruckReff, LegalNum, Manager
	),

	cte_LastPrev AS (
    SELECT
        v.TruckReff,
        v.OrderRef,
        v.EndFact,
        v.RouteReff,
        ROW_NUMBER() OVER (
            PARTITION BY v.TruckReff
            ORDER BY 
                -- ПРИОРИТЕТ 1: Текущая фактическая заявка (Пункт 1)
                CASE 
                    WHEN v.StartFact IS NOT NULL 
                     AND CAST(v.StartFact AS date) <= CAST(GETDATE() AS date)
                     AND (v.EndFact IS NULL OR CAST(v.EndFact AS date) >= CAST(GETDATE() AS date))
                    THEN 1
                -- ПРИОРИТЕТ 2: Текущая плановая заявка (Пункт 2)
                    WHEN v.StartPlan IS NOT NULL 
                     AND CAST(v.StartPlan AS date) <= CAST(GETDATE() AS date)
                     AND (v.EndPlan IS NULL OR CAST(v.EndPlan AS date) >= CAST(GETDATE() AS date))
                    THEN 2
                -- ПРИОРИТЕТ 3: Последний завершенный заказ (Пункт 3)
                    ELSE 3 
                END ASC,
                -- Внутри приоритета №3 сортируем по дате завершения (как в вашей старой CTE)
                v.EndFact DESC
        ) AS rn
    FROM pbi.v_DimOrders v
    WHERE 
        -- Исключаем пустые/нулевые идентификаторы грузовиков
        v.TruckReff <> '00000000000000000000000000000000'
        -- Проверяем условия отбора (в скобках, чтобы AND применялся ко всей группе)
        AND (
            (v.EndFact IS NOT NULL AND v.EndFact >= DATEADD(MONTH, -3, CAST(GETDATE() AS date)))
            OR (v.StartFact IS NOT NULL AND CAST(v.StartFact AS date) <= CAST(GETDATE() AS date) AND (v.EndFact IS NULL OR CAST(v.EndFact AS date) >= CAST(GETDATE() AS date)))
            OR (v.StartPlan IS NOT NULL AND CAST(v.StartPlan AS date) <= CAST(GETDATE() AS date) AND (v.EndPlan IS NULL OR CAST(v.EndPlan AS date) >= CAST(GETDATE() AS date))))
)

	select 
		C.TruckReff, 
		LegalNum, 
		Manager,
		1 as Counter,
		case 
			when (Count0+Count1+Count2+Count3+Count4+Count5+Count6+Count7+Count8+Count9+Remont0+Remont1+Remont2+Remont3+Remont4+Remont5+Remont6+Remont7+Remont8+Remont9) = 0 then 'Немає плану'
			when (Count0+Count1+Count2+Remont0+Remont1+Remont2) > 0 AND (Count3+Count4+Count5+Count6+Count7+Count8+Count9+Remont3+Remont4+Remont5+Remont6+Remont7+Remont8+Remont9) = 0 then 'План на 1-3 дні'
			when (Count0+Count1+Count2+Count3+Count4+Remont0+Remont1+Remont2+Remont3+Remont4) > 0 AND (Count5+Count6+Count7+Count8+Count9+Remont5+Remont6+Remont7+Remont8+Remont9) = 0 then 'План на 4-5 днів'
			when (Count0+Count1+Count2+Count3+Count4+Count5+Count6+Count7+Count8+Count9+Remont0+Remont1+Remont2+Remont3+Remont4+Remont5+Remont6+Remont7+Remont8+Remont9) > 0 then 'План на 6+ днів'
			else 'ОК'
		end as Status,
        q.QuotaIsDone,
		l.GeoZone
		--, R.*
	from cte_AllCounts C
	left join #Repairs R ON R.TruckRef = C.TruckReff 

    left join (
        select 
            TruckRef, 
            SUM(MarginPerDay) / SUM(QuotaPerDAY) as QuotaIsDone
        from pbi.TargetTableFact
        where TargetDate = CAST(GETDATE() AS Date)
        group by TruckRef
    ) AS q on q.TruckRef = C.TruckReff

	left join(
		SELECT 
			l.TruckReff,
			 --OrderRef AS PrevOrderRef,
			 --EndFact  AS PrevEndFact,
			 --RouteReff AS RouteReff,
			 --p.CountryWhere,
			 --t.LegalNum,
			p.RouteType AS GeoZone
		FROM cte_LastPrev l
		inner JOIN pbi.v_PivotRoute p ON p.PivotRouteRef = l.RouteReff
		WHERE rn = 1
	) AS l on l.TruckReff = C.TruckReff

	drop table #AllOrders
	drop table #Orders
	drop table #Repairs

GO