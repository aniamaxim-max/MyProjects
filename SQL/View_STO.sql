-- SELECT * from pbi.v_Repair

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_Repair' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_Repair
GO

Create view pbi.v_Repair AS
Select
    r._IDRRef AS RepairRef,
	_Number AS RepairNum,
    IIF(r._Date_Time >= DATEFROMPARTS(4001,1,1), DateADD(Year, -2000, r._Date_Time), r._Date_Time) AS RepairDate,
	IIF(r._Fld18748 >= DATEFROMPARTS(4001,1,1), DateADD(Year, -2000, r._Fld18748), r._Fld18748) AS StartDate,
	IIF(r._Fld18749 >= DATEFROMPARTS(4001,1,1), DateADD(Year, -2000, r._Fld18749), r._Fld18749) AS EndDate,
	r._Fld33801RRef AS ClientRef,
	CASE 
		WHEN r._Fld33801RRef IN (0x9E948968B27C8A3E11E8EE2C39C1CCB0, 0xACEFD32FEC9A2DE011E680D1B1EAD954, 0x89E602B31CC3E40111EE99AEECF87850) 
		THEN 'Внутрішній'
	ELSE 'Зовнішній' END AS ClientType,
	CASE 
		WHEN r._Fld18746RRef IN (0x00, 0xA6E68EF6A5647F8A49532EB3F7178F2D) THEN 'Готівка'
		WHEN r._Fld18746RRef = 0xA898F61A93C68B8041A200C955389745 THEN 'Безготівка'
	ELSE 'Інше' END AS PaymentMethod,
	r._Fld18747_RRRef AS StorageRef,
	r._Fld18750RRef AS VehicleRef,
    r._Fld18756RRef AS RepairTypeRef, 
    -- _Reference266._Description AS 'Назва типу', 
    -- _Reference123._Description AS 'Контрагент',
	r._Fld18757RRef AS RepairStatement,
    -- CONVERT(Varchar(MAX), _InfoRg23603._Fld23604RRef, 2) AS 'TruckReffRepair', 
    --_InfoRg23603._Fld23607 As 'CheckTruckID', 
	r._Fld18769 AS ToolCostVAT,
	r._Fld18770 AS WorkCostVAT,
	r._Fld18771 AS RepairCost
from _Document671 r
go

/*inner join _Reference33771 on _Reference33771._IDRRef = r._Fld18750RRef 
inner join _Reference123 on _Reference123._IDRRef = r._Fld33801RRef 
inner join _InfoRg23603 on REPLACE(_InfoRg23603._Fld23607, ' ', '') = REPLACE(_Reference33771._Fld33798, ' ', '')  
    OR  
    CONVERT(Varchar(MAX), _InfoRg23603._Fld23604RRef, 2) = CONVERT(Varchar(MAX), _Reference33771._Fld34106RRef, 2) 
inner join _Reference266 on _Reference266._IDRRef = r._Fld18756RRef 
where r._Marked = 0 and
	r._Fld18764 = 1*/

-----------------------------------------------------------------------------------------------------------

 -- SELECT CONVERT(Varchar(50), RepairTypeRef, 2), RepairType from pbi.v_RepairType

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_RepairType' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_RepairType
GO

Create view pbi.v_RepairType AS

SELECT 
	_IDRRef AS RepairTypeRef,
	_Description AS RepairType
from _Reference266 -- типы обслуживания
go


 -- SELECT * from _Reference123 - контрагенти
 -- SELECT * from _InfoRg23603 или _Reference167 - тс
 -- SELECT * from _Reference33771 - автомобили клиентов

-----------------------------------------------------------------------------------------

--SELECT
--	CONVERT(Varchar(MAX), RepairRef, 2) AS RepairRef,
--	ApplicationName, 
--	CONVERT(Varchar(MAX), WorkRef, 2) AS WorkRef,
--	Amount,
--	WorkSum,
--	WorkSumWithoutVat,
--	CONVERT(Varchar(MAX), Currency, 2) AS CurrencyRef
-- from pbi.v_WorkRepair

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_WorkRepair' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_WorkRepair
GO

Create view pbi.v_WorkRepair AS
 select 
	rw._Document671_IDRRef AS RepairRef,
	rw._Fld33862 AS ApplicationName,
	rw._Fld18785RRef AS WorkRef,
	rw._Fld18787 AS Amount,
	rw._Fld18789 AS WorkSum,
	rw._Fld18791 AS WorkSumVat,
	rw._Fld18789 - rw._Fld18791 AS WorkSumWithoutVat,
	rw._Fld18792RRef AS Currency
 
 from _Document671_VT18783 rw -- роботи
 go

 ----------------------------------------------------------------------------------------

SELECT 
	CONVERT(Varchar(MAX), RepairRef, 2) AS RepairRef,
	ApplicationName, 
 	CONVERT(Varchar(MAX), ToolRef, 2) AS ToolRef,
  	Amount,
 	ToolSum,
 	WorkSumWithoutVat,
 	CONVERT(Varchar(MAX), Currency, 2) AS CurrencyRef

from pbi.v_ToolRepair

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_ToolRepair' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_ToolRepair
GO

Create view pbi.v_ToolRepair AS
 select 
	rt._Document671_IDRRef AS RepairRef,
	rt._Fld33863 AS ApplicationName,
	rt._Fld18796RRef AS ToolRef,
	rt._Fld18797 AS Amount,
	rt._Fld18801 AS ToolSum,
	rt._Fld18803 AS ToolSumVat,
	rt._Fld18801 - rt._Fld18803 AS WorkSumWithoutVat,
	rt._Fld18804RRef AS Currency
 
 from _Document671_VT18794 rt -- матеріали
 go

 SELECT 
	CONVERT(VARCHAR(MAX), r.RepairRef, 2) AS RepairRef,
	r.RepairNum,
	r.RepairDate,
	r.EndDate,
	r.ClientType,
	w.WorkSum, 
	t.ToolSum
 
from pbi.v_Repair r
inner join 
	(select	
		RepairRef,
		SUM(WorkSumWithoutVat) AS WorkSum
	from pbi.v_WorkRepair
	group by RepairRef) w
 ON w.RepairRef = r.RepairRef

inner join 
	(select	
		RepairRef,
		SUM(WorkSumWithoutVat) AS ToolSum
	from pbi.v_ToolRepair
	group by RepairRef) t
ON t.RepairRef = r.RepairRef







