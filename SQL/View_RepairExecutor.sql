-- SELECT * from pbi.v_RepairExecutor

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_RepairExecutor' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_RepairExecutor
GO

Create view pbi.v_RepairExecutor AS

select
	_Fld18825RRef AS ExecutorRef,
	_Fld33803_RRRef AS WorkRef,
	_Fld34007 AS Reason,
	_Document671_IDRRef AS RepairRef


from _Document671_VT18823

go

-- SELECT * from pbi.v_DimExecutor

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimExecutor' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimExecutor
GO

Create view pbi.v_DimExecutor AS

select
	IIF(_Period >= DATEFROMPARTS(4001,1,1), DateADD(Year, -2000, _Period), _Period) AS PeriodDate,
	_RecorderTRef AS RecordRef,
	_Fld21945RRef AS ExecutorRef,
	_Fld21946RRef AS DepartmentRef
from _InfoRg21944
-- where _Fld21946RRef = 0x9510D2F17FCDA9B711EB8D6DF233E8E0
-- 0x9510D2F17FCDA9B711EB8D6DF233E8E0 - Department - реставрація, або інші 
