/*
SELECT * 
FROM OPENQUERY(LOOPBACK, 
'
    EXEC work.pbi.Repair 
    WITH RESULT SETS 
    (
        (
            RepairRef			VARCHAR(50),
			EndDate				DATE,
			[Type]				VARCHAR(MAX),
			RecordType			VARCHAR(MAX),
			WorkSumWithoutVat	NUMERIC(10,2)
        )
    )
');
*/

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'Repair' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.Repair;
GO

Create PROCEDURE pbi.Repair AS
	SET NOCOUNT ON


--находим подразделение работ
IF OBJECT_ID('tempdb..#WorkData') IS NOT NULL 
    DROP TABLE #WorkData;

SELECT 
	RepairRef,
	[TYPE],
	SUM(WorkSumWithoutVat) AS WorkSumWithoutVat,
	CAST('Repair' AS Varchar(20)) as RecordType
INTO #WorkData
FROM (
	SELECT 
		r.RepairRef, 
		CASE
			WHEN t.DepartmentRef = 0x9510D2F17FCDA9B711EB8D6DF233E8E0 then 'Ремонтно-реставраційний цех'
			else 'Авторемонтна майстерня' end as [TYPE],
		WorkSumWithoutVat / ISNULL(TotalCount, 1) AS WorkSumWithoutVat

	from pbi.v_WorkRepair wr
	inner join pbi.v_Repair r ON r.RepairRef = wr.RepairRef
	left join pbi.v_RepairExecutor i ON i.RepairRef = r.RepairRef AND wr.WorkRef = i.WorkRef
	left join (
		select RepairRef, WorkRef, COUNT(*) AS TotalCount
		from pbi.v_RepairExecutor
		group by RepairRef, WorkRef
	) c on c.RepairRef = r.RepairRef AND wr.WorkRef = c.WorkRef
	outer apply (
		select top 1 DepartmentRef   
			from pbi.v_DimExecutor e 
		where e.ExecutorRef = i.ExecutorRef and e.PeriodDate <= r.RepairDate
		order by e.PeriodDate desc
	) t
	where r.RepairTypeRef = 0x80A602B31CC3E40111EEAF9FFD1D70D1

	UNION ALL

	SELECT 
		r.RepairRef, 
		CASE
			WHEN r.RepairTypeRef = 0x80A602B31CC3E40111EEAF9FCBFB77E0 THEN 'Дніпровська філія'
			WHEN r.RepairTypeRef IN (0x80A602B31CC3E40111EEAF9FCBFB77E1, 0x80A602B31CC3E40111EEAF9FD5975670, 
				0x80A602B31CC3E40111EEAFA00B6D3A80, 0x80A602B31CC3E40111EEAF9FDDB06590) THEN 'Авторемонтна майстерня'
			WHEN r.RepairTypeRef IN (0x80A602B31CC3E40111EEAF9FF54EFF40, 0x80A602B31CC3E40111EEAF9FF54EFF41, 
				0x80B802B31CC3E40111F1028A30143CD1, 0x80A602B31CC3E40111EEAFA00529AEB0) THEN 'Ремонтно-реставраційний цех'
			WHEN r.RepairTypeRef = 0x80A602B31CC3E40111EEAF9FFD1D70D0 THEN 'Мийний комплекс'
			else 'Інше' end as [TYPE],
		wr.WorkSumWithoutVat
	
	from pbi.v_WorkRepair wr
	inner join pbi.v_Repair r ON r.RepairRef = wr.RepairRef
	where r.RepairTypeRef <> 0x80A602B31CC3E40111EEAF9FFD1D70D1
) T
GROUP BY RepairRef, [TYPE]


-- Якщо таблиця вже існує, видаляємо її перед створенням
IF OBJECT_ID('tempdb..#TempRepairData') IS NOT NULL 
    DROP TABLE #TempRepairData;

SELECT 
	RepairRef,
    ApplicationName,
    [TYPE],
    SUM(WorkSumWithoutVat) AS WorkSum
INTO #TempRepairData
FROM (
    SELECT 
        r.RepairRef,
		wr.ApplicationName,
        CASE
            WHEN t.DepartmentRef = 0x9510D2F17FCDA9B711EB8D6DF233E8E0 THEN 'Ремонтно-реставраційний цех'
            ELSE 'Авторемонтна майстерня' 
        END AS [TYPE],
        WorkSumWithoutVat / TotalCount AS WorkSumWithoutVat
    FROM pbi.v_WorkRepair wr
    INNER JOIN pbi.v_Repair r ON r.RepairRef = wr.RepairRef
    INNER JOIN pbi.v_RepairExecutor i ON i.RepairRef = r.RepairRef AND wr.WorkRef = i.WorkRef
    INNER JOIN (
        SELECT RepairRef, WorkRef, COUNT(*) AS TotalCount
        FROM pbi.v_RepairExecutor
        GROUP BY RepairRef, WorkRef
    ) c ON c.RepairRef = r.RepairRef AND wr.WorkRef = c.WorkRef
    CROSS APPLY (
        SELECT TOP 1 DepartmentRef   
        FROM pbi.v_DimExecutor e 
        WHERE e.ExecutorRef = i.ExecutorRef AND e.PeriodDate <= r.RepairDate
        ORDER BY e.PeriodDate DESC
    ) t

    UNION ALL

    SELECT 
        r.RepairRef,
		wr.ApplicationName,
        CASE
            WHEN r.RepairTypeRef = 0x80A602B31CC3E40111EEAF9FCBFB77E0 THEN 'Дніпровська філія'
            WHEN r.RepairTypeRef IN (0x80A602B31CC3E40111EEAF9FCBFB77E1, 0x80A602B31CC3E40111EEAF9FD5975670, 
                0x80A602B31CC3E40111EEAFA00B6D3A80, 0x80A602B31CC3E40111EEAF9FDDB06590) THEN 'Авторемонтна майстерня'
            WHEN r.RepairTypeRef IN (0x80A602B31CC3E40111EEAF9FF54EFF40, 0x80A602B31CC3E40111EEAF9FF54EFF41, 
                0x80B802B31CC3E40111F1028A30143CD1, 0x80A602B31CC3E40111EEAFA00529AEB0) THEN 'Ремонтно-реставраційний цех'
			WHEN r.RepairTypeRef = 0x80A602B31CC3E40111EEAF9FFD1D70D0 THEN 'Мийний комплекс'
            ELSE 'Інше' 
        END AS [TYPE],
        wr.WorkSumWithoutVat
    FROM pbi.v_WorkRepair wr
    INNER JOIN pbi.v_Repair r ON r.RepairRef = wr.RepairRef
    WHERE r.RepairTypeRef <> 0x80A602B31CC3E40111EEAF9FFD1D70D1
) AS SourceQuery
GROUP BY 
    RepairRef, ApplicationName, [TYPE];

CREATE NONCLUSTERED INDEX [idx_TempRepairData] ON #TempRepairData ([RepairRef],[ApplicationName]) INCLUDE ([TYPE],[WorkSum])

INSERT INTO #WorkData
SELECT 
	f.RepairRef,
	[TYPE],
	--s.TotalWorkSum, 
	--f.WorkSum /  s.TotalWorkSum AS WorkPercent,
	t.ToolSum * f.WorkSum /  s.TotalWorkSum,
	'Tools'
FROM #TempRepairData f
inner join (
	SELECT 
		RepairRef,
		ApplicationName,
		SUM(WorkSum) AS TotalWorkSum
	FROM #TempRepairData
	GROUP BY RepairRef, ApplicationName) s ON f.RepairRef = s.RepairRef AND f.ApplicationName = s.ApplicationName
inner join (
	select RepairRef, ApplicationName, SUM(WorkSumWithoutVat) AS ToolSum
	from pbi.v_ToolRepair 
	group by RepairRef, ApplicationName) t ON t.RepairRef = f.RepairRef AND t.ApplicationName = f.ApplicationName

order by RepairRef

INSERT INTO #WorkData
SELECT 
    t.RepairRef, 
	CASE
			WHEN r.RepairTypeRef = 0x80A602B31CC3E40111EEAF9FCBFB77E0 THEN 'Дніпровська філія'
			WHEN r.RepairTypeRef IN (0x80A602B31CC3E40111EEAF9FCBFB77E1, 0x80A602B31CC3E40111EEAF9FD5975670, 
				0x80A602B31CC3E40111EEAFA00B6D3A80, 0x80A602B31CC3E40111EEAF9FDDB06590) THEN 'Авторемонтна майстерня'
			WHEN r.RepairTypeRef IN (0x80A602B31CC3E40111EEAF9FF54EFF40, 0x80A602B31CC3E40111EEAF9FF54EFF41, 
				0x80B802B31CC3E40111F1028A30143CD1, 0x80A602B31CC3E40111EEAFA00529AEB0) THEN 'Ремонтно-реставраційний цех'
			WHEN r.RepairTypeRef = 0x80A602B31CC3E40111EEAF9FFD1D70D0 THEN 'Мийний комплекс'
			else 'Інше' end as [TYPE],
	t.WorkSumWithoutVat,
	'ToolsNoWork'
FROM pbi.v_ToolRepair t
inner join pbi.V_Repair r ON r.RepairRef = t.RepairRef
WHERE NOT EXISTS (
    SELECT 1 
    FROM pbi.v_WorkRepair w 
    WHERE w.RepairRef = t.RepairRef 
      AND w.ApplicationName = t.ApplicationName
)

SELECT 
	CONVERT(VARCHAR(50), #WorkData.RepairRef, 2) AS RepairRef,
	r.EndDate,
	[Type],
	RecordType,
	WorkSumWithoutVat
FROM #WorkData
inner join pbi.v_Repair r on r.RepairRef = #WorkData.RepairRef 
where --cast(r.EndDate as date) between '2026-04-27' and '2026-05-03' AND 
	r.RepairStatement IN (0x83CBCB2FAC4604DE4AB9587B31C56434, 0x8B8866C6E02866BF40585199A5CB259B)
	AND r.RepairTypeRef NOT IN (0xB98502B31CC3E40111EE166D1C2E79CC, 0x80A602B31CC3E40111EEAF9FE4CF0F21, 0x80A602B31CC3E40111EEAF9FD5975671,
				0x80A602B31CC3E40111EEAF9FDDB06591, 0x80B902B31CC3E40111F14795824A8E79, 0x80A602B31CC3E40111EEAF9FE4CF0F20, 0xBC2602B31CC3E40111EF2E0D246BD720,
				0x80A602B31CC3E40111EEAF9FEC5B6EA0, 0x80A602B31CC3E40111EEAF9FEC5B6EA1, 0xBC2602B31CC3E40111EF2D4D611B14A1, 0x80A602B31CC3E40111EEAFA00529AEB1,
				0xBC2602B31CC3E40111EF2E0CFC78AEB6)
--	and r.RepairRef = 0x80B902B31CC3E40111F142CF14B861E4
order by #WorkData.RepairRef

DROP TABLE #TempRepairData;
DROP TABLE #WorkData;

GO